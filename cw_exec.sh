#!/bin/bash
# cw_exec.sh v3 - 32G 端封装: SSH 到 16G 调 CodeWhale exec, 提取代码落盘
# v3 (2026-06-24) 升级:
#   - 加 fallback: 16G 失败 → 自动重试 → 切到 32G 本地直接调 OpenAI 兼容 API
#   - 加 SQLite 日志: 每次调用记录到 ~/.hermes/llm_log.db (token/latency/cost/model/verdict)
#   - 加健康检查: 16G 不可达时跳过 SSH 直走本地 fallback
#
# 用法 (向后兼容 v2):
#   ./cw_exec.sh "<prompt>" <output_file> [project_root] [--no-write]
#
# v3 新参数:
#   ./cw_exec.sh "<prompt>" <output> [root] [--no-fallback]  # 关闭 fallback
#   ./cw_exec.sh "<prompt>" <output> [root] [--no-log]        # 关闭日志
#   ./cw_exec.sh --stats                                       # 看调用统计
#
# 示例:
#   ./cw_exec.sh "写一个身份证校验函数" validators/id_card.py
#   ./cw_exec.sh "写一个 hello 函数" /tmp/hello.py /tmp
#   ./cw_exec.sh --stats

set -euo pipefail

# ─── 配置 ───────────────────────────────────────────────
PROMPT="${1:-}"
OUTPUT="${2:-}"
PROJECT_ROOT="${3:-$(pwd)}"
shift 3 2>/dev/null || shift 2 2>/dev/null || true

# 解析额外参数
NO_FALLBACK=""
NO_LOG=""
STATS_ONLY=""
while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --no-fallback) NO_FALLBACK="1"; shift ;;
    --no-log) NO_LOG="1"; shift ;;
    --stats) STATS_ONLY="1"; shift ;;
    *) shift ;;
  esac
done

SSH_TARGET="chenye@192.168.2.2"
MODEL="deepseek-v4-pro"
LOG_DB="${HOME}/.hermes/llm_log.db"
HEALTH_TIMEOUT=5  # 16G 健康检查超时 (秒)
RETRY_MAX=2        # 16G 重试次数

# ─── stats 子命令 (优先处理) ───────────────────────────
if [[ "$STATS_ONLY" == "1" ]]; then
  if [[ ! -f "$LOG_DB" ]]; then
    echo "📊 无日志 (db 不存在: $LOG_DB)"
    exit 0
  fi
  sqlite3 -header -column "$LOG_DB" "
    SELECT
      substr(ts, 12, 5) AS time,
      model,
      verdict,
      printf('%.2fs', latency_sec) AS latency,
      tokens_in || '/' || tokens_out AS tokens,
      printf('\$%.4f', cost_usd) AS cost
    FROM llm_calls
    ORDER BY ts DESC
    LIMIT 20;
  "
  echo ""
  echo "📊 汇总 (按 verdict):"
  sqlite3 -header -column "$LOG_DB" "
    SELECT verdict, COUNT(*) AS n, printf('$%.4f', SUM(cost_usd)) AS total_cost
    FROM llm_calls GROUP BY verdict ORDER BY n DESC;
  "
  echo ""
  echo "📊 总花费 (本月):"
  sqlite3 "$LOG_DB" "
    SELECT printf('本月总花费: \$%.4f (USD)', SUM(cost_usd)) FROM llm_calls
    WHERE ts LIKE strftime('%Y-%m', 'now') || '%';
  "
  exit 0
fi

# ─── 参数校验 ─────────────────────────────────────────
if [[ -z "$PROMPT" || -z "$OUTPUT" ]]; then
  echo "用法: $0 <prompt> <output_file> [project_root] [--no-fallback] [--no-log]"
  echo "      $0 --stats"
  exit 1
fi

# 目标路径
TARGET_PATH="$PROJECT_ROOT/$OUTPUT"
TARGET_DIR="$(dirname "$TARGET_PATH")"
mkdir -p "$TARGET_DIR"

# ─── 工具函数 ─────────────────────────────────────────
init_log_db() {
  [[ "$NO_LOG" == "1" ]] && return
  mkdir -p "$(dirname "$LOG_DB")"
  sqlite3 "$LOG_DB" <<'SQL' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS llm_calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  model TEXT,
  prompt_chars INTEGER,
  output_chars INTEGER,
  tokens_in INTEGER,
  tokens_out INTEGER,
  latency_sec REAL,
  cost_usd REAL,
  fallback_used INTEGER DEFAULT 0,
  verdict TEXT,
  prompt_preview TEXT,
  error TEXT
);
CREATE INDEX IF NOT EXISTS idx_ts ON llm_calls(ts DESC);
SQL
}

log_call() {
  local model="$1" tokens_in="$2" tokens_out="$3" latency="$4"
  local cost="$5" fallback="$6" verdict="$7" error="${8:-}"
  [[ "$NO_LOG" == "1" ]] && return
  init_log_db
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local prompt_chars=${#PROMPT}
  local prompt_preview="${PROMPT:0:80}"
  sqlite3 "$LOG_DB" <<SQL >/dev/null 2>&1 || true
INSERT INTO llm_calls (ts, model, prompt_chars, tokens_in, tokens_out, latency_sec, cost_usd, fallback_used, verdict, prompt_preview, error)
VALUES ('$ts', '$model', $prompt_chars, $tokens_in, $tokens_out, $latency, $cost, $fallback, '$verdict', '$prompt_preview', '$error');
SQL
}

# ─── 健康检查: 16G 是否可达 ───────────────────────────
check_16g_alive() {
  ssh -o BatchMode=yes -o ConnectTimeout="$HEALTH_TIMEOUT" "$SSH_TARGET" 'true' 2>/dev/null
}

# ─── SSH agent 自检 ───────────────────────────────────
if ! ssh-add -l 2>/dev/null | grep -q "chenye@chenyedeMac-mini"; then
  echo "⚠️  SSH agent 缺 key，自动加载..."
  ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>&1 | head -2
fi

# ─── 实际调用 (带 fallback) ──────────────────────────
START_TIME=$(date +%s)
call_16g_v4pro() {
  local attempt=$1
  echo "🤖 调用 16G CodeWhale ($MODEL) 第 $attempt 次..."
  echo "📝 Prompt: $PROMPT"
  echo "📂 目标: $TARGET_PATH"
  echo "---"

  RAW=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" \
      "codewhale exec --non-interactive --model $MODEL '$PROMPT'" 2>&1) || {
    echo "❌ SSH 或 CodeWhale exec 失败 (尝试 $attempt)"
    return 1
  }

  # 调试警告
  if [[ "$RAW" == *"DEEPSEEK_BASE_URL not set"* ]]; then
    echo "⚠️  [debug] DEEPSEEK_BASE_URL not set (16G 端建议设环境变量)" >&2
  fi

  # 提取 markdown python 代码块
  CODE=$(echo "$RAW" | awk '
    /^```python$/{flag=1; next}
    /^```$/      {flag=0; next}
    flag          {print}
  ')

  # 兜底: 检测无代码响应
  if [[ -z "$CODE" ]]; then
    CODE=$(echo "$RAW" | grep -v "^DEBUG" | grep -vE "(Test successful|Model:|mode:)")
    if [[ -z "$CODE" ]]; then
      echo "❌ CodeWhale 没返回代码块 (尝试 $attempt)" >&2
      return 2
    fi
  fi

  # 写入文件
  echo "$CODE" > "$TARGET_PATH"
  local end_time=$(date +%s)
  local latency=$((end_time - START_TIME))
  local size=$(wc -c < "$TARGET_PATH")
  local tokens_in=$(( ${#PROMPT} / 4 ))   # 粗估: 4 字符 ≈ 1 token (英文)
  local tokens_out=$(( size / 4 ))
  # DeepSeek v4-pro 定价: $0.27/M input, $1.10/M output
  local cost=$(python3 -c "print(f'{($tokens_in * 0.27 + $tokens_out * 1.10) / 1000000:.6f}')")

  echo "✅ 已写入: $TARGET_PATH ($size bytes)"
  echo "   延迟: ${latency}s, 估 token: in=$tokens_in / out=$tokens_out, 估费用: \$$cost"

  # 记录日志
  log_call "$MODEL" "$tokens_in" "$tokens_out" "$latency" "$cost" "0" "KEEP"

  return 0
}

# ─── Fallback: 32G 本地直接调 OpenAI 兼容 API ─────────
fallback_32g_local() {
  echo "🔄 Fallback: 32G 本地调 OpenAI 兼容 API (绕过 16G)..."

  # 检查是否有 OPENAI_API_KEY 或 MINIMAX_API_KEY
  local api_key="${OPENAI_API_KEY:-${MINIMAX_API_KEY:-}}"
  local api_url="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
  local model_fb="gpt-4o-mini"

  if [[ -z "$api_key" ]]; then
    echo "❌ Fallback 失败: 32G 本地未设 OPENAI_API_KEY / MINIMAX_API_KEY" >&2
    return 1
  fi

  # 用 curl 调 chat/completions
  local response
  response=$(curl -sL --max-time 60 "$api_url/chat/completions" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
prompt = '''$PROMPT'''
print(json.dumps({
    'model': '$model_fb',
    'messages': [{'role': 'user', 'content': prompt}],
    'temperature': 0.3
}))
")") || {
    echo "❌ Fallback 调 API 失败" >&2
    return 1
  }

  # 提取 content
  local content
  content=$(echo "$response" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['choices'][0]['message']['content'])
except Exception as e:
    print('PARSE_ERR:', e, file=sys.stderr)
    sys.exit(1)
" 2>&1) || {
    echo "❌ Fallback 解析响应失败: $response" >&2
    return 1
  }

  # 提取 python 代码块 (同 v2 逻辑)
  local code
  code=$(echo "$content" | awk '
    /^```python$/{flag=1; next}
    /^```$/      {flag=0; next}
    flag          {print}
  ')

  if [[ -z "$code" ]]; then
    code=$(echo "$content" | grep -v "^DEBUG" | grep -vE "(Test successful|Model:|mode:)")
  fi

  if [[ -z "$code" ]]; then
    echo "❌ Fallback 没返回代码块" >&2
    return 2
  fi

  echo "$code" > "$TARGET_PATH"
  local end_time=$(date +%s)
  local latency=$((end_time - START_TIME))
  local size=$(wc -c < "$TARGET_PATH")
  local tokens_in=$(( ${#PROMPT} / 4 ))
  local tokens_out=$(( size / 4 ))
  # gpt-4o-mini 定价: $0.15/M input, $0.60/M output
  local cost=$(python3 -c "print(f'{($tokens_in * 0.15 + $tokens_out * 0.60) / 1000000:.6f}')")

  echo "✅ Fallback 已写入: $TARGET_PATH ($size bytes)"
  echo "   模型: $model_fb, 延迟: ${latency}s, 估费用: \$$cost"

  # 记录日志 (fallback=1)
  log_call "$model_fb" "$tokens_in" "$tokens_out" "$latency" "$cost" "1" "FALLBACK"

  return 0
}

# ─── 主流程: 健康检查 → 重试 → fallback ──────────────
init_log_db

echo "═══════════════════════════════════════"
echo "📡 cw_exec.sh v3 (fallback + logging)"
echo "═══════════════════════════════════════"

# 检查 16G 是否可达
if check_16g_alive; then
  echo "✅ 16G 健康, 走主路径"
else
  echo "⚠️  16G 不可达 (健康检查失败)"
  if [[ "$NO_FALLBACK" == "1" ]]; then
    log_call "$MODEL" 0 0 0 0 0 "SSH_DOWN" "16G 不可达"
    exit 1
  fi
  fallback_32g_local
  exit $?
fi

# 主路径: 重试 N 次
attempt=1
while [[ $attempt -le $RETRY_MAX ]]; do
  if call_16g_v4pro $attempt; then
    exit 0
  fi
  attempt=$((attempt + 1))
  echo "⚠️  第 $((attempt-1)) 次失败, 重试..."
  sleep 2
done

# 重试 N 次都失败 → fallback
echo "❌ 16G 多次失败, 切 fallback"
if [[ "$NO_FALLBACK" == "1" ]]; then
  log_call "$MODEL" 0 0 0 0 0 "RETRY_FAILED" "重试 $RETRY_MAX 次都失败"
  exit 1
fi
fallback_32g_local
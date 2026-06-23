# cw_exec.sh v3 (2026-06-24)

## 升级点 vs v2

| 能力 | v2 | v3 |
|---|---|---|
| 调 16G deepseek-v4-pro | ✅ | ✅ |
| 失败重试 | ❌ | ✅ 2 次 |
| 16G 健康检查 | ❌ | ✅ 5s 超时 |
| Fallback 到 32G 本地 API | ❌ | ✅ 调 OpenAI/MiniMax 兼容 |
| SQLite 调用日志 | ❌ | ✅ 11 字段 (token/latency/cost) |
| 调用统计 --stats | ❌ | ✅ 最近 20 条 + 汇总 |
| 关闭 fallback `--no-fallback` | — | ✅ |
| 关闭日志 `--no-log` | — | ✅ |

## 用法

```bash
# 向后兼容 v2
./cw_exec.sh "写 hello 函数" hello.py
./cw_exec.sh "写 hello 函数" hello.py /tmp/myproject
./cw_exec.sh "写 hello 函数" hello.py /tmp --no-write

# v3 新增
./cw_exec.sh --stats                                    # 看日志
./cw_exec.sh "写 hello" hello.py /tmp --no-fallback    # 关闭 fallback
./cw_exec.sh "写 hello" hello.py /tmp --no-log          # 关闭日志
```

## Fallback 触发条件

1. **健康检查失败**: ssh 16G 5s 超时 → 立即走 fallback
2. **主路径 2 次失败**: 每次重试间隔 2s → fallback
3. **禁用**: `--no-fallback` 参数

## Fallback 模型

默认 `gpt-4o-mini` (OpenAI 兼容),需环境变量:
- `OPENAI_API_KEY` 或 `MINIMAX_API_KEY`
- `OPENAI_BASE_URL` (默认 OpenAI)

## SQLite 日志

路径: `~/.hermes/llm_log.db`

字段:
- `ts` UTC 时间
- `model` (deepseek-v4-pro / gpt-4o-mini)
- `tokens_in` / `tokens_out` (估算: 4 字符 ≈ 1 token)
- `latency_sec`
- `cost_usd` (DeepSeek: $0.27/M in, $1.10/M out; GPT-4o-mini: $0.15/$0.60)
- `fallback_used` (0 或 1)
- `verdict` (KEEP / FALLBACK / SSH_DOWN / RETRY_FAILED)
- `error` 错误信息

## 价格参考

| 模型 | 输入 ($/M token) | 输出 ($/M token) |
|---|---|---|
| deepseek-v4-pro | 0.27 | 1.10 |
| gpt-4o-mini | 0.15 | 0.60 |

## 测试记录 (2026-06-24)

```
✅ 主路径 KEEP (3s, $0.0001)
✅ 主路径 KEEP (11s, $0.0001)
✅ SSH_DOWN 路径触发 (verdict=SSH_DOWN, fallback 已尝试)
```

## v2 备份

`cw_exec.sh.v2.bak` (86 行, 3027 bytes)

## 已知限制

1. **Token 估算粗**: 4 字符 ≈ 1 token 对英文近似,中文/代码差异大
2. **价格是估算**: 用官方公开定价,实际可能因批量/合同不同
3. **Fallback 模型硬编码**: 暂未实现多模型路由(待 #3 延后项触发再做)
4. **无并发**: 单调用,如需批量用 caller 并行

## 相关

- Skill: `~/.hermes/skills/devops/cross-device-llm-orchestration/`
- 健康检查脚本: 内嵌 SSH `true` 测试
- 失败重试: 固定 2 次, 间隔 2s (可改 RETRY_MAX 变量)
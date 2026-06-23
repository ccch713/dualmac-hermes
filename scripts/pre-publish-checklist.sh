#!/bin/bash
# pre-publish-checklist.sh
# 在 push 到 GitHub / Gitea 之前,自动检查隐私泄漏
# 用法: ./pre-publish-checklist.sh /path/to/project

set -e

PROJECT_DIR="${1:-$(pwd)}"
cd "$PROJECT_DIR" || exit 1

echo "═══════════════════════════════════════"
echo "🔍 pre-publish checklist"
echo "═══════════════════════════════════════"
echo "Project: $PROJECT_DIR"
echo ""

ERRORS=0
WARNINGS=0

# 检查 1: 真实姓名 (中英文) — 排除 scripts/pre-publish-checklist.sh 自己 (含检测关键词)
echo "--- 1. 真实姓名检查 ---"
if grep -rn -E "(陈烨|chenye|chenye|CCCH)" --exclude-dir=.git --exclude-dir=node_modules --exclude="pre-publish-checklist.sh" . 2>/dev/null; then
    echo "❌ 发现真实姓名引用"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ 未发现真实姓名"
fi
echo ""

# 检查 2: 内部项目名 (口腔/ESG/hotwuhan 等) — 排除 OpenTracy/dualmac-hermes (公开参考)
echo "--- 2. 内部项目名检查 ---"
if grep -rn -i -E "(oral-clinic|口腔|ESG[ -]?SaaS|hotwuhan|wuhan-travel|esg-assessment)" --exclude-dir=.git --exclude-dir=node_modules . 2>/dev/null | head -5; then
    echo "⚠️  发现内部项目名 (你确认是否公开)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ 未发现内部项目名"
fi
echo ""

# 检查 3: LLM 标记
echo "--- 3. LLM 提交标记检查 ---"
if git log --all --oneline | grep -iE "\[(LLM|AI|GPT|claude|deepseek|minimax|chatgpt|gemini)\]"; then
    echo "❌ commit 信息含 LLM/AI 标记"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ commit 信息无 LLM 标记"
fi
echo ""

# 检查 4: git config user.name (避免真名)
echo "--- 4. git author 检查 ---"
AUTHOR=$(git log -1 --format="%an" 2>/dev/null || echo "")
AUTHOR_EMAIL=$(git log -1 --format="%ae" 2>/dev/null || echo "")
echo "最近 commit author: $AUTHOR <$AUTHOR_EMAIL>"
if echo "$AUTHOR" | grep -qE "(陈烨|chenye|chenye)"; then
    echo "⚠️  author 字段含真实姓名 (历史 commit 改起来要 force push, 评估后再做)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ author 字段无真名"
fi
echo ""

# 检查 5: remote URL 嵌入 token
echo "--- 5. remote URL token 泄漏检查 ---"
LEAKED=$(git remote -v 2>/dev/null | grep -E "https?://[^@/]+:[^@/]+@" || true)
if [ -n "$LEAKED" ]; then
    echo "❌ remote URL 嵌入了用户名:密码 格式的 token!"
    echo "$LEAKED"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ remote URL 无 token 泄漏"
fi
echo ""

# 检查 6: 协议文件
echo "--- 6. LICENSE 文件 ---"
if [ -f "LICENSE" ] || [ -f "LICENSE.md" ]; then
    echo "✅ LICENSE 存在"
else
    echo "⚠️  缺 LICENSE 文件 (推 GitHub 强烈建议有)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 检查 7: README
echo "--- 7. README ---"
if [ -f "README.md" ]; then
    LINES=$(wc -l < README.md)
    echo "✅ README.md 存在 ($LINES 行)"
    if [ "$LINES" -lt 30 ]; then
        echo "⚠️  README 太短 (< 30 行), 不利于 first impression"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "❌ 缺 README.md"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 检查 8: .gitignore 是否合理
echo "--- 8. .gitignore ---"
if [ -f ".gitignore" ]; then
    # 检查是否排除了常见敏感文件
    REQUIRED=(".env" "*.pem" "id_rsa" "*.key")
    MISSING=()
    for pat in "${REQUIRED[@]}"; do
        if ! grep -q "$pat" .gitignore 2>/dev/null; then
            MISSING+=("$pat")
        fi
    done
    if [ ${#MISSING[@]} -gt 0 ]; then
        echo "⚠️  .gitignore 缺模式: ${MISSING[*]}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ .gitignore 含常见敏感模式"
    fi
else
    echo "⚠️  缺 .gitignore"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 总结
echo "═══════════════════════════════════════"
echo "📊 检查结果"
echo "═══════════════════════════════════════"
echo "Errors:   $ERRORS (必须修)"
echo "Warnings: $WARNINGS (建议处理)"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "❌ 有 $ERRORS 个错误, 不能 push"
    exit 1
fi

if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  有 $WARNINGS 个警告, 确认无问题后可继续 push"
    exit 0
fi

echo "✅ 全部检查通过, 可以 push"
exit 0
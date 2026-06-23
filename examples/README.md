# Examples

## 1. 最简单的用法:写一个函数

```bash
$ cw "用 Python 写一个 add 函数" /tmp/add.py /tmp
🤖 调用 16G CodeWhale (deepseek-v4-pro) 第 1 次...
📝 Prompt: 用 Python 写一个 add 函数
📂 目标: /tmp/add.py
---
✅ 已写入: /tmp/add.py (188 bytes)
   延迟: 3s, 估 token: in=6 / out=47, 估费用: $0.000053

$ cat /tmp/add.py
def add(a, b):
    return a + b
```

## 2. 写文件到具体项目目录

```bash
$ cd ~/workspace/myproject
$ cw "写一个数据库连接池" db/pool.py .
✅ 已写入: db/pool.py (892 bytes)
```

## 3. 看本月花了多少

```bash
$ cw --stats
time   model            verdict   latency  tokens   cost
-----  ---------------  --------  -------  -------  -------
16:14  deepseek-v4-pro  KEEP      3.00s    6/47     $0.0001
16:14  deepseek-v4-pro  KEEP      11.00s   2/122    $0.0001
16:14  deepseek-v4-pro  SSH_DOWN  0.00s    0/0      $0.0000

📊 汇总 (按 verdict):
verdict   n  total_cost
--------  -  ----------
KEEP      2  $0.0002
SSH_DOWN  1  $0.0000

📊 总花费 (本月):
本月总花费: $0.0002 (USD)
```

## 4. 集成到 shell 工具

```bash
# alias
alias ai='cw "$1" /tmp/ai_out.py /tmp && cat /tmp/ai_out.py'

# 函数
ai_review() {
  cw "评审这段代码,给出改进建议" /tmp/review.md /tmp < "$1"
  cat /tmp/review.md
}
```

## 5. 集成到 vim/nvim

`~/.vimrc`:
```vim
function! AIExplain()
  let l:result = system('cw "解释这段代码" /tmp/ai.md /tmp && cat /tmp/ai.md')
  new
  put =l:result
endfunction

nnoremap <leader>ae :call AIExplain()<CR>
```

## 6. 集成到 Makefile

```makefile
.PHONY: gen-test
gen-test:
	cw "为 $(FILE) 写 pytest 测试" tests/test_$(FILE).py .
```

## 7. 跑 Claude Code / CodeWhale 全套流程

```bash
# 让 16G 帮你 review PR
cw "review 以下 diff,给出改进建议" /tmp/review.md /tmp << 'EOF'
$(git diff main..HEAD)
EOF
```

---

## 真实场景示例(2026-06)

我在做这些项目时实际用过:

### 口腔诊所多模型对比项目
```bash
# 让 DS 帮写 v2.0 完整代码 (DS-pro-CW 版)
cw "为口腔诊所 SaaS 写完整的 v2.0 后端代码,SQLAlchemy + JWT + Alembic" oral_clinic_v2.py oral-clinic-compare/DS-pro-CW版/

# 跑 3 个 LLM 横向对比
for model in deepseek-v4-pro deepseek-v4-flash gpt-4o-mini; do
  cw "写口腔诊所 SaaS v2.0 后端,要求与 $model 版本完全独立" oral_$model.py oral-clinic-compare/
done
```

### ESG SaaS 报告生成
```bash
# 让 DS 写报告生成骨架
cw "写一个 Python 脚本:输入 16 家评级机构 + 指标 JSON,输出 Markdown 报告" generator.py esg-assessment-saas/scripts/esg_report/
```

### cw_exec.sh 自身迭代
```bash
# 让 DS 加 fallback 能力
cw "给 cw_exec.sh 加 SQLite 日志 + 16G fallback" cw_exec_v3.sh ~/.hermes/skills/.../templates/

# 跑测试,验证 KEEP / SSH_DOWN / FALLBACK 三态
```
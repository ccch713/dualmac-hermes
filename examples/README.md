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

## 7. 跑 AI Agent 全套流程

```bash
# 让 16G 帮你 review PR
cw "review 以下 diff,给出改进建议" /tmp/review.md /tmp << 'EOF'
$(git diff main..HEAD)
EOF
```

---

## 实战示例

下面是一些常见场景的示例代码。

### 跨项目对比生成

```bash
# 让 LLM 帮写某个独立模块,作为对比候选
cw "写一个 Python 模块:输入用户列表,返回分页结果" module.py compare-project/
```

### 报告生成骨架

```bash
# 让 LLM 写一个脚本:输入 JSON 数据,输出 Markdown 报告
cw "写一个 Python 脚本:输入 16 家评级机构 + 指标 JSON,输出 Markdown 报告" generator.py my-project/scripts/
```

### 工具脚本迭代

```bash
# 让 LLM 给现有脚本加新能力
cw "给 cw_exec.sh 加 SQLite 日志 + fallback 能力" cw_exec_v3.sh my-skill/templates/

# 跑测试,验证 KEEP / SSH_DOWN / FALLBACK 三态
```
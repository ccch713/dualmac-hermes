# Troubleshooting

## SSH 不通 16G

### 症状
```
ssh: connect to host 192.168.2.2 port 22: Connection refused
```

### 诊断步骤
```bash
# 1. 检查网络通不通
ping 192.168.2.2

# 2. 检查 SSH 服务在 16G 上开没开
ssh chenye@192.168.2.2 'sudo systemsetup -getremotelogin'
# 应返回 "Remote Login: On"

# 3. 如果返回 "Remote Login: Off"
ssh chenye@192.168.2.2 'sudo systemsetup -setremotelogin on'
```

### 16G 上 SSH 开了但还是连不上
```bash
# 看 sshd 进程在不在
ssh chenye@192.168.2.2 'ps aux | grep sshd'

# 看防火墙
ssh chenye@192.168.2.2 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate'
```

---

## cw_exec.sh 报错 "DEEPSEEK_BASE_URL not set"

### 症状
```
⚠️  [debug] DEEPSEEK_BASE_URL not set (16G 端建议设环境变量)
```

### 原因
16G 端 CodeWhale 配置 DeepSeek provider 时,环境变量没传过去。

### 解决
在 16G 端:
```bash
# ~/.zshrc 或 ~/.bash_profile 加
export DEEPSEEK_API_KEY="sk-..."
export DEEPSEEK_BASE_URL="https://api.deepseek.com/v1"

# 重启 shell 或 source
source ~/.zshrc
```

---

## CodeWhale 卡住

### 症状
`codewhale exec` 半天没返回

### 诊断
```bash
ssh chenye@192.168.2.2 'ps aux | grep codewhale'
```

### 解决
```bash
# 杀掉重启
ssh chenye@192.168.2.2 'pkill -f codewhale; codewhale --version'

# 如果经常卡,降级到 codewhale tui 而非 exec
```

---

## SQLite 日志打不开

### 症状
```
sqlite3.OperationalError: unable to open database file
```

### 解决
```bash
mkdir -p ~/.hermes
ls -la ~/.hermes/llm_log.db

# 如果不存在
~/.hermes/scripts/cw_exec.sh "test" /tmp/test.py /tmp
# 第一次调用会自动创建 db
```

---

## Fallback 触发但 key 没设

### 症状
```
❌ Fallback 失败: 32G 本地未设 OPENAI_API_KEY / MINIMAX_API_KEY
```

### 解决
```bash
# 32G 加环境变量
export OPENAI_API_KEY="sk-..."
# 或
export MINIMAX_API_KEY="ey..."

# 写进 ~/.zshrc 永久生效
echo 'export MINIMAX_API_KEY="..."' >> ~/.zshrc
```

---

## 雷雳桥掉线

### 症状
```bash
$ ping 192.168.2.2
PING 192.168.2.2 (192.168.2.2): 56 data bytes
Request timeout for icmd_seq 0
```

### 诊断
```bash
# 检查 Thunderbolt 物理连接
system_profiler SPThunderboltDataType | head -30

# 检查 bridge0 状态
ifconfig bridge0
```

### 解决
```bash
# 1. 重插雷雳线
# 2. 系统设置 → 通用 → 共享 → 关 Thunderbolt Bridge, 等 5 秒, 再开
# 3. 重启两台 Mac
```

---

## cw_exec.sh 调 16G 慢

### 症状
每次调 16G 都要 10+ 秒

### 原因
- 16G 端 CodeWhale 第一次冷启动慢
- SSH 每次都新连接

### 解决
- 复用 SSH 连接:在 `~/.ssh/config` 加 `ControlMaster auto` 和 `ControlPath ~/.ssh/master-%r@%h:%p`
- 改用 mosh(适合不稳定连接)
- 调通本地 ollama,完全跳过 16G

---

## AHE Loop 报"ruff 未找到"

### 症状
```
PEP8 警告: -1
ruff_note: ruff 未安装, 跳过
```

### 解决
```bash
# macOS + Python 3.9 用户态
pip3 install --user -i https://pypi.tuna.tsinghua.edu.cn/simple/ ruff

# 验证
~/Library/Python/3.9/bin/ruff --version
```

---

## 如何提 Issue

提 Issue 时附:
```bash
# 1. 环境
uname -a
sw_vers
ifconfig bridge0 | grep inet

# 2. cw_exec.sh --stats
cw --stats

# 3. 完整日志
~/.hermes/llm_log.db  # 可发, SQLite 文件
```

我在 GitHub 上看: https://github.com/ccch713/dualmac-hermes/issues
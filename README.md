# dualmac-hermes

> Dual Mac Mini Thunderbolt bridge + Hermes Agent dual-machine collaboration

**Turn your two Macs into one supercomputer — 32G runs Hermes Agent orchestration, 16G runs LLM inference, Thunderbolt 5 direct connection, zero cloud dependency.**

[中文版说明请见下方](#中文说明) | [Chinese version below](#中文说明)

---

## What is this

I use two Mac Mini M4 (one 32G, one 16G) connected via Thunderbolt 5,
building a **fully local, zero-cloud-dependency dual-machine collaboration architecture**:

- **32G (orchestrator)**: Hermes Agent, Git, Obsidian, all local scripts
- **16G (LLM inference + message gateway)**: CodeWhale + DeepSeek, as inference backend
- **Thunderbolt 5 direct connection**: 192.168.2.1 ↔ 192.168.2.2, latency < 1ms
- **SSH agent forwarding**: 32G → 16G remote calls are seamless

Use cases:
- Want to run LLMs but don't want to send data to the cloud
- Single machine memory not enough (32G can't run 70B models)
- Want Agent orchestration + local LLM inference, refuse to pay OpenAI monthly
- 1-2 person small team wants to save money + no cloud dependency

---

## Quick Start

### Hardware Requirements

| Device | Minimum | Recommended |
|--------|---------|-------------|
| Mac 1 (orchestrator) | M2 / 16GB | M4 / 32GB |
| Mac 2 (inference) | M2 / 16GB | M4 / 16GB+ |
| Connection | USB-C | Thunderbolt 4/5 |
| OS | macOS 13+ | macOS 15+ |

### 1. Thunderbolt Bridge Setup

**On both Macs**:
```bash
# Mac 1 (orchestrator) gets 192.168.2.1
sudo ifconfig bridge0 inet 192.168.2.1 netmask 255.255.255.0

# Mac 2 (inference) gets 192.168.2.2
sudo ifconfig bridge0 inet 192.168.2.2 netmask 255.255.255.0

# Verify connectivity
ping 192.168.2.2  # from Mac 1
```

**Persistence**: Use LaunchDaemon to auto-configure IP at boot (see `references/thunderbolt-setup.md`)

### 2. SSH Key Authentication

```bash
# On Mac 1, generate key (if not already)
ssh-keygen -t rsa -b 4096

# Copy public key to Mac 2
ssh-copy-id your_username@192.168.2.2

# Test
ssh your_username@192.168.2.2 'echo OK'
```

### 3. Install CodeWhale + DeepSeek on Mac 2

```bash
# Install CodeWhale (see https://codewhale.dev for details)
curl -fsSL https://codewhale.dev/install.sh | sh

# Configure DeepSeek provider
codewhale login
# Select DeepSeek, paste your API key
```

### 4. Install cw_exec.sh on Mac 1

```bash
# Copy cw_exec.sh to your PATH
sudo cp cw_exec.sh /usr/local/bin/cw
chmod +x /usr/local/bin/cw

# Test
cw "Write a Python add function" /tmp/add.py /tmp
cat /tmp/add.py
```

### 5. Integrate with Hermes Agent (Optional)

Add `cw_exec.sh` to Hermes toolchain:
- `~/.hermes/skills/devops/cross-device-llm-orchestration/templates/cw_exec.sh`
- Or your Agent framework's corresponding tool path

---

## Core Files

| File | Description |
|------|-------------|
| `cw_exec.sh` | 32G → SSH → 16G LLM call wrapper (10.3 KB) |
| `LICENSE` | Apache-2.0 |
| `references/thunderbolt-setup.md` | Detailed Thunderbolt bridge config (LaunchDaemon persistence) |
| `references/troubleshooting.md` | Common issues (SSH fail / 16G down / CodeWhale stuck) |
| `examples/` | Usage examples |

---

## cw_exec.sh Capabilities

```bash
# Basic: call LLM to generate code
cw "Write a hello function" hello.py

# Specify output directory
cw "Write a database connection pool" db/pool.py /Users/me/project

# View call statistics
cw --stats

# Disable fallback (16G only)
cw "prompt" file.py /tmp --no-fallback

# Disable logging (no SQLite)
cw "prompt" file.py /tmp --no-log
```

### Fallback Mechanism (Key)

```
Call 16G DeepSeek → 2 retries fail → auto-switch to 32G local OpenAI/MiniMax API
```

- Health check: 5s SSH timeout
- Retry: 2 times, 2s interval
- Fallback: default `gpt-4o-mini` (modifiable in script)

### Logging

All calls written to `~/.hermes/llm_log.db`:
```sql
SELECT time, model, verdict, latency_sec, tokens_in, tokens_out, cost_usd
FROM llm_calls
ORDER BY ts DESC LIMIT 20;
```

---

## Real-World Data (2026-06 Tested)

5 runs:

| # | Operation | Latency | Cost |
|---|-----------|---------|------|
| 1 | v4-pro writes add function | 3s | $0.0001 |
| 2 | v4-pro writes multiply function | 11s | $0.0001 |
| 3 | Simulated SSH down, triggers fallback | 0s | $0.0000 |
| 4 | Simulated SSH down, no fallback key | 0s | (SSH_DOWN) |
| 5 | (Production runs) | - | - |

---

## What I Use This For

1. **AI coding assistant**: CodeWhale exec writes code remotely, local IDE gets it instantly
2. **AI code review**: DeepSeek v4-pro gives review opinions
3. **Agent task orchestration**: Hermes Agent dispatches multiple LLM calls
4. **Personal knowledge base**: Obsidian + local LLM, no cloud dependency

---

## Why Apache-2.0

- Most permissive open source license, allows anyone to use, commercialize, modify
- Includes **patent grant**, protects contributors from patent litigation
- Most enterprise legal teams approve (unlike AGPL which gets rejected)
- You're free to commercialize or change license in the future

**Why not AGPL-3.0**: AGPL is an anti-SaaS weapon. While it can stop big companies from closing source,
it scares away 90% of potential contributors/integrators from touching your project.
OPC prioritizes influence, not nuclear weapons.

---

## Roadmap

- [x] cw_exec.sh v3 (fallback + SQLite logging)
- [x] Thunderbolt bridge LaunchDaemon persistence
- [ ] multi-model routing (CHEAPEST/FASTEST/BEST)
- [ ] Health check dashboard (Grafana)
- [ ] AHE Loop cross-machine collaboration (local + remote)
- [ ] Hermes skill: dualmac topology auto-discovery

---

## Contributing

Issues / PRs welcome. **No CLA required** (I don't plan to maintain a large project).

Before submitting:
```bash
bash -n your_script.sh   # bash syntax
shellcheck your_script.sh  # if shellcheck installed
```

---

## License

Apache-2.0 — see [LICENSE](LICENSE)

---

## Author

ccch713 — 2026-06-24

If you set up dual machines using this scheme, let me know: just open an Issue.

---

## Related Projects

- [Hermes Agent](https://hermes-agent.nousresearch.com) — Orchestration framework
- [CodeWhale](https://codewhale.dev) — TUI code Agent
- [Mascarade](https://github.com/electron-rare/mascarade) — Multi-machine LLM orchestration reference
- [OpenTracy](https://github.com/OpenTracy/OpenTracy) — AHE Loop algorithm source

(Last two I researched but didn't actually use — OPC doesn't need their complexity, just borrow ideas)

---

# 中文说明

> 双 Mac Mini 雷雳桥 + Hermes Agent 双机协作方案

**让你的两台 Mac 变成一台超级计算机——32G 跑 Hermes Agent 调度,16G 跑 LLM 推理,雷雳5 直连,零配置零云依赖。**

---

## 这是什么

我用两台 Mac Mini M4(一台 32G、一台 16G)通过 Thunderbolt 5 直连,
搭建了一个**纯本地、零云依赖的双机协作架构**:

- **32G(执行中心)**:跑 Hermes Agent、Git、Obsidian、所有本地脚本
- **16G(LLM 推理 + 消息入口)**:跑 CodeWhale + DeepSeek,作为推理后端
- **雷雳5 直连**:192.168.2.1 ↔ 192.168.2.2,延迟 < 1ms
- **SSH agent 转发**:32G 远程调用 16G 完全无感

主要场景:
- 想跑 LLM 但不愿把数据发到云
- 单机内存不够(32G 也跑不动 70B 模型时)
- 想要 Agent 编排 + 本地 LLM 推理,不愿付 OpenAI 月费
- 1-2 人小团队想省钱 + 不依赖任何云服务

---

## 快速开始

### 硬件要求

| 设备 | 最低配置 | 推荐配置 |
|------|----------|----------|
| Mac 1 (执行中心) | M2 / 16GB | M4 / 32GB |
| Mac 2 (推理后端) | M2 / 16GB | M4 / 16GB+ |
| 连接 | USB-C | Thunderbolt 4/5 |
| 系统 | macOS 13+ | macOS 15+ |

### 1. 雷雳网桥配置

**在两台 Mac 上**:
```bash
# Mac 1 (执行中心) 配 192.168.2.1
sudo ifconfig bridge0 inet 192.168.2.1 netmask 255.255.255.0

# Mac 2 (推理后端) 配 192.168.2.2
sudo ifconfig bridge0 inet 192.168.2.2 netmask 255.255.255.0

# 验证互通
ping 192.168.2.2  # 从 Mac 1
```

**持久化**:用 LaunchDaemon 开机自动配 IP(详见 `references/thunderbolt-setup.md`)

### 2. SSH 密钥免密登录

```bash
# 在 Mac 1 生成密钥(若没有)
ssh-keygen -t rsa -b 4096

# 把公钥拷到 Mac 2
ssh-copy-id 你的用户名@192.168.2.2

# 测试
ssh 你的用户名@192.168.2.2 'echo OK'
```

### 3. 在 Mac 2 安装 CodeWhale + DeepSeek

```bash
# CodeWhale 安装(详见 https://codewhale.dev)
curl -fsSL https://codewhale.dev/install.sh | sh

# 配置 DeepSeek provider
codewhale login
# 选 DeepSeek,粘贴你的 API key
```

### 4. 在 Mac 1 安装 cw_exec.sh

```bash
# 复制 cw_exec.sh 到 PATH
sudo cp cw_exec.sh /usr/local/bin/cw
chmod +x /usr/local/bin/cw

# 测试
cw "用 Python 写一个 add 函数" /tmp/add.py /tmp
cat /tmp/add.py
```

### 5. 集成 Hermes Agent(可选)

把 `cw_exec.sh` 加到 Hermes 的工具链:
- `~/.hermes/skills/devops/cross-device-llm-orchestration/templates/cw_exec.sh`
- 或你的 Agent 框架对应的 tool 路径

---

## 核心文件

| 文件 | 说明 |
|------|------|
| `cw_exec.sh` | 32G → SSH → 16G 调 LLM 的封装脚本 (10.3 KB) |
| `LICENSE` | Apache-2.0 |
| `references/thunderbolt-setup.md` | 雷雳桥详细配置(LaunchDaemon 持久化) |
| `references/troubleshooting.md` | 常见问题(SSH 不通/16G 挂了/CodeWhale 卡住) |
| `examples/` | 使用样例 |

---

## cw_exec.sh 能力

```bash
# 基础: 调 LLM 生成代码
cw "写一个 hello 函数" hello.py

# 指定输出目录
cw "写一个数据库连接池" db/pool.py /Users/me/project

# 看调用统计
cw --stats

# 关闭 fallback (只走 16G)
cw "prompt" file.py /tmp --no-fallback

# 关闭日志 (不写 SQLite)
cw "prompt" file.py /tmp --no-log
```

### Fallback 机制(关键)

```
调 16G DeepSeek → 失败 2 次 → 自动切 32G 本地调 OpenAI/MiniMax API
```

- 健康检查:5s SSH 超时
- 重试:2 次,间隔 2s
- Fallback:默认 `gpt-4o-mini`(可在脚本改)

### 日志

所有调用写 `~/.hermes/llm_log.db`:
```sql
SELECT time, model, verdict, latency_sec, tokens_in, tokens_out, cost_usd
FROM llm_calls
ORDER BY ts DESC LIMIT 20;
```

---

## 实战数据(2026-06 实测)

5 次:

| # | 操作 | 延迟 | 费用 |
|---|------|------|------|
| 1 | 调 v4-pro 写 add 函数 | 3s | $0.0001 |
| 2 | 调 v4-pro 写 multiply 函数 | 11s | $0.0001 |
| 3 | 模拟 SSH 挂,触发 fallback | 0s | $0.0000 |
| 4 | 模拟 SSH 挂,无 fallback key | 0s | (SSH_DOWN) |
| 5 | (生产环境真实跑) | - | - |

---

## 我用它做什么

1. **AI 编程助手**:CodeWhale exec 远程写代码,本地 IDE 即时拿到
2. **AI 代码评审**:DeepSeek v4-pro 给出 review 意见
3. **Agent 任务编排**:Hermes Agent 调度多个 LLM 调用
4. **个人知识库**:Obsidian + 本地 LLM,不依赖云

---

## 为什么 Apache-2.0

- 最宽松的开源协议,允许任何人用、商用、改
- 含**专利授权**,保护贡献者不被专利诉讼
- 大多数企业法务通过(不像 AGPL 会被拒)
- 你未来想商用或换协议都自由

**不选 AGPL-3.0 的原因**:AGPL 是反 SaaS 武器,虽然能阻止大公司闭源,
但会让 90% 的潜在贡献者/集成者不敢碰你的项目。OPC 优先影响力,不要核武器。

---

## 路线图

- [x] cw_exec.sh v3 (fallback + SQLite 日志)
- [x] 雷雳桥 LaunchDaemon 持久化配置
- [ ] multi-model routing (CHEAPEST/FASTEST/BEST)
- [ ] 健康检查 dashboard (Grafana)
- [ ] AHE Loop 跨机协作(本机 + 远机)
- [ ] Hermes skill: dualmac 拓扑自动发现

---

## 贡献

欢迎提 Issue / PR。**不需要 CLA**(我不打算维护大型项目)。

提交前:
```bash
bash -n your_script.sh   # bash 语法
shellcheck your_script.sh  # 如安装了 shellcheck
```

---

## 协议

Apache-2.0 — 详见 [LICENSE](LICENSE)

---

## 作者

ccch713 — 2026-06-24

如果你用了这个方案搭起了双机,欢迎告诉我:开个 Issue 就行。

---

## 相关项目

- [Hermes Agent](https://hermes-agent.nousresearch.com) — 调度框架
- [CodeWhale](https://codewhale.dev) — TUI 代码 Agent
- [Mascarade](https://github.com/electron-rare/mascarade) — 多机 LLM 编排参考
- [OpenTracy](https://github.com/OpenTracy/OpenTracy) — AHE Loop 算法来源

(最后两个我研究过但没真用——单 OPC 用不上它们的复杂度,借鉴思路就行)
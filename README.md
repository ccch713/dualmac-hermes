# dualmac-hermes

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
ssh-copy-id chenye@192.168.2.2

# 测试
ssh chenye@192.168.2.2 'echo OK'
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

## 实战数据(2026-06-23 实测)

我跑了 5 次:

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

陈烨 (ccch713) — 武汉,2026-06-24

如果你用了这个方案搭起了双机,欢迎告诉我:开个 Issue 就行。

---

## 相关项目

- [Hermes Agent](https://hermes-agent.nousresearch.com) — 调度框架
- [CodeWhale](https://codewhale.dev) — TUI 代码 Agent
- [Mascarade](https://github.com/electron-rare/mascarade) — 多机 LLM 编排参考
- [OpenTracy](https://github.com/OpenTracy/OpenTracy) — AHE Loop 算法来源

(最后两个我研究过但没真用——单 OPC 用不上它们的复杂度,借鉴思路就行)
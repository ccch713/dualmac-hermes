# 雷雳桥详细配置

## 物理准备

你需要:
- 2 台 Mac(M4 推荐,旧 M2 也行)
- 一根 Thunderbolt 4 或 5 线
- 两台 Mac 都启用了 Thunderbolt Bridge(Mac 共享设置 → 通用 → 共享 → Thunderbolt Bridge)

## 检查网卡

```bash
# 看 bridge0 是否有 IPv4
ifconfig bridge0 | grep inet

# 如果是空,说明 IPv4 没配
```

## 临时配 IP

```bash
# Mac 1 (执行中心)
sudo ifconfig bridge0 inet 192.168.2.1 netmask 255.255.255.0

# Mac 2 (推理后端)
sudo ifconfig bridge0 inet 192.168.2.2 netmask 255.255.255.0
```

## 持久化 LaunchDaemon

**不要**用 /etc/rc.local(macOS 不支持)。
**用** LaunchDaemon:

### Mac 1 的 plist

`/Library/LaunchDaemons/com.thunderbolt5.staticroute.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.thunderbolt5.staticroute</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>ifconfig bridge0 inet 192.168.2.1 netmask 255.255.255.0 && route add -net 192.168.2.0/24 -interface bridge0</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

Mac 2 同理,IP 改 `192.168.2.2`。

### 加载

```bash
sudo launchctl load /Library/LaunchDaemons/com.thunderbolt5.staticroute.plist
sudo launchctl start com.thunderbolt5.staticroute

# 重启后验证
sudo reboot
ifconfig bridge0 | grep inet  # 应该看到 192.168.2.1
ping 192.168.2.2  # 验证互通
```

## ⚠️ 常见坑

### bridge0 没 IPv4

如果重启后 `ifconfig bridge0 | grep inet` 看不到 IPv4,
**问题**:旧版 plist 只配了 route 没配 IP。

**解决**:plist 用 `bash -c '...'` 包裹 ifconfig + route 一气呵成。

### weak host model 污染 conntrack

macOS 在 WiFi + bridge0 双网卡时,可能两条默认路由打架,
导致 WebUI(32G 自己)挂起。

**症状**:
- 从 32G ping 16G 通
- 但浏览器开 32G localhost 服务卡死

**诊断**:
```bash
netstat -rn  # 看是否有 2 条 default
```

**解决**:把 WiFi 路由加 metric(高优先级走 WiFi,内网走 bridge0):
```bash
sudo route add -net 192.168.2.0/24 -interface bridge0
```

## 双机互通后

SSH 配置:`~/.ssh/config`:

```
Host minimax-16g
    HostName 192.168.2.2
    User chenye
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
```

测试:
```bash
ssh minimax-16g 'echo OK'
```

测延迟:
```bash
ping -c 10 minimax-16g   # 雷雳桥应该 < 1ms
```

---

## 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| bridge0 没 IPv4 | plist 顺序错 | 用 bash -c 包裹 ifconfig+route |
| ping 通但 SSH 卡 | weak host model | 加 route -net 192.168.2.0/24 -interface bridge0 |
| 16G 重启后不通 | 持久化 plist 没加载 | launchctl load + start |
| WebUI 挂 | 上面 weak host | 同上 |
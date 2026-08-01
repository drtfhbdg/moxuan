---
title: "服务器 SSH 安全配置：密钥登录与 fail2ban 联动"
date: 2024-06-12T22:00:00+08:00
draft: false
tags: ["Linux", "SSH", "安全", "服务器"]
categories: ["服务器运维"]
description: "分享我配置服务器 SSH 安全的一些做法，包括禁用密码登录、使用密钥认证、修改端口和配合 fail2ban 防御暴力破解。"
---

我的 VPS 刚买回家的时候，每天打开 auth.log 都能看到一堆来自世界各地的登录尝试。用户名大多是 `root`、`admin`、`test`、`oracle` 这些，一看就是暴力破解脚本在扫全网。

虽然密码我设得挺复杂的，但看着这些日志还是心里发毛。后来花了一个下午把 SSH 好好加固了一下，登录尝试量直接断崖式下降。这篇记录一下我做的几件事。

## 第一件事：创建普通用户，禁用 root 直接登录

很多 VPS 默认只允许 root 登录，这其实挺危险的。root 权限太大，一旦密码被猜出来，对方可以为所欲为。

我的做法是创建一个普通用户，日常操作都用它。需要 root 权限的时候再用 `sudo`。

```bash
# 添加用户
useradd -m -s /bin/bash moxuan

# 设置密码
passwd moxuan

# 添加到 sudo 组
usermod -aG sudo moxuan
```

然后修改 SSH 配置，禁止 root 直接登录：

```bash
nano /etc/ssh/sshd_config
```

找到这一行并修改：

```text
PermitRootLogin no
```

改完之后不要直接重启 SSH，先开一个新的终端窗口测试普通用户能不能登录。确认没问题再重启：

```bash
systemctl restart sshd
```

这里强烈建议保留一个 root 的会话窗口做保险，防止配置错了把自己锁在外面。

## 第二件事：用密钥登录，禁用密码登录

密码再复杂，也比不上密钥安全。密钥认证的原理是非对称加密，私钥留在本地，公钥放到服务器上。没有私钥的人即使知道密码也登不上来。

### 在本地生成密钥对

如果你还没有 SSH 密钥，先在本地生成：

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

ed25519 是目前比较推荐的算法，安全性高，密钥也短。如果你的客户端太老不支持，可以用 `rsa -b 4096`。

生成过程中会提示你输入密钥保存路径和密码。密码可以留空，这样登录就不用输密码。但我建议还是设一个，安全性更高。

### 把公钥复制到服务器

最方便的方式是用 `ssh-copy-id`：

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub moxuan@服务器IP
```

如果没有这个命令，也可以手动复制。在本地看公钥内容：

```bash
cat ~/.ssh/id_ed25519.pub
```

然后到服务器的 `~/.ssh/authorized_keys` 文件里粘贴：

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

注意 `.ssh` 目录权限是 700，`authorized_keys` 是 600，权限不对 SSH 会拒绝读取。

### 测试密钥登录

新开一个终端，用普通用户和密钥登录：

```bash
ssh -i ~/.ssh/id_ed25519 moxuan@服务器IP
```

如果不需要输入密码就登录成功了，说明密钥配置好了。

### 禁用密码登录

确认密钥登录没问题之后，就可以彻底关闭密码登录了：

```text
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
```

全部改成 `no`，然后重启 sshd。

## 第三件事：修改默认端口

SSH 默认 22 端口是扫描器的重点照顾对象。改成高位端口，比如 2222、8022 这些，能减少 90% 以上的无聊扫描。

修改 `sshd_config`：

```text
Port 2222
```

注意防火墙也要放行新端口。如果你用 ufw：

```bash
ufw allow 2222/tcp
ufw delete allow 22/tcp
```

重启 sshd 后，登录命令要加上 `-p`：

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 moxuan@服务器IP
```

为了省事，我在本地 `~/.ssh/config` 里配置了别名：

```text
Host myvps
    HostName 服务器IP
    Port 2222
    User moxuan
    IdentityFile ~/.ssh/id_ed25519
```

之后直接 `ssh myvps` 就能登录。

## 第四件事：fail2ban 联动防御

改端口能减少大部分扫描，但总有一些执着的扫描器会继续尝试。这时候就需要 fail2ban 出场了。

fail2ban 的原理是监控日志，发现某个 IP 短时间内多次失败登录，就自动把它封禁一段时间。

安装：

```bash
apt update
apt install fail2ban -y
```

创建自定义配置文件：

```bash
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
nano /etc/fail2ban/jail.local
```

修改 SSH 相关部分：

```ini
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

- `port`：改成你实际的 SSH 端口。
- `maxretry`：允许失败次数。
- `bantime`：封禁时间，单位秒，3600 就是 1 小时。
- `findtime`：在这个时间内累计失败次数超过 maxretry 就封禁。

启动并设置开机自启：

```bash
systemctl start fail2ban
systemctl enable fail2ban
```

查看封禁状态：

```bash
fail2ban-client status sshd
fail2ban-client status sshd banned
```

## 第五件事：其他可选加固

除了上面这些，还有一些锦上添花的配置：

**禁用空密码**

```text
PermitEmptyPasswords no
```

**限制登录用户**

```text
AllowUsers moxuan
```

**缩短认证超时**

```text
LoginGraceTime 60
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

**禁用 X11 转发**

```text
X11Forwarding no
```

这些改不改看个人需求，但 PermitRootLogin、PasswordAuthentication、Port 这三项强烈建议改。

## 最后验证

全部改完之后，用 `sshd -t` 检查配置文件语法：

```bash
sshd -t
```

没有输出就是没问题。然后重启 sshd：

```bash
systemctl restart sshd
```

再用另一台机器或者新窗口测试登录，确认一切正常。

如果你发现登录不上了，大概率是防火墙规则或者 SSH 配置写错了。这时候只能通过 VPS 控制台的 VNC 救援模式进去修复。所以再次强调，改 SSH 之前一定要做好备份，或者保留一个已登录的会话窗口。

## 总结

我的 SSH 加固思路就是三道防线：

1. **禁用 root 登录，使用普通用户 + sudo**
2. **关闭密码认证，改用密钥登录**
3. **修改默认端口 + fail2ban 自动封禁**

做完这三件事之后，我的服务器每天收到的暴力破解尝试从几千次降到了几乎为零。其实安全措施很多时候不需要多复杂，把基础做好就已经超过绝大多数服务器了。

---
title: "看了一眼 auth.log，被扫端口的脚本哥整破防了，火速改用密钥登录"
date: 2024-02-12T19:30:00+08:00
draft: false
tags: ["Linux", "安全", "SSH"]
categories: ["服务器运维"]
---

今天闲着没事，登录服务器 `tail -f /var/log/auth.log` 看了一眼，好家伙，满屏的 `Failed password for root`。估计是哪个无聊的脚本在盲扫 22 端口暴力破解密码。

虽然我的密码挺复杂的，但天天被人这么敲门也烦。干脆把密码登录关了，强制改用 SSH 密钥。

**配置过程留档：**
1. 本机终端生成密钥对：`ssh-keygen -t rsa -C "my_vps"`
2. 把公钥推到服务器端：`ssh-copy-id root@你的服务器IP`
3. 登录服务器，修改 `/etc/ssh/sshd_config`：
   - `PasswordAuthentication no` （彻底关掉密码登录）
   - 顺手把默认的 22 端口改成了个五位数的高位端口。
4. 重启 ssh 服务：`systemctl restart sshd`

现在清净了，再扫也扫不进来了。
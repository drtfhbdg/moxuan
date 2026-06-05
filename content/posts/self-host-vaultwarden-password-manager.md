---
title: "受够了密码满天飞，用 Vaultwarden 搭建私人密码管家服务器"
date: 2024-12-22T12:30:00+08:00
draft: false
tags: ["密码管理", "Vaultwarden", "自我托管", "安全"]
categories: ["架构部署"]
---

**信任危机**
各大平台的账号密码越来越多，有些乱设的记不住，设成一样的又怕撞库。存在浏览器自带的密码夹里也不放心。
看上了大名鼎鼎的 Bitwarden，但官方镜像太重了，最终选择了基于 Rust 语言轻量级重写的 `Vaultwarden`。

**极其轻量的部署**
因为是 Rust 写的，内存占用仅需十几兆。配合 Docker 部署极其简单：
```yaml
version: '3'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    environment:
      # 禁用别人注册，这是我的私人领地
      - SIGNUPS_ALLOWED=false
    volumes:
      - ./vw-data:/data
    ports:
      - 8080:80
```

**安全性强化配置**
这玩意儿毕竟存着我的全部身家性命，我给它上了三重锁：
1. 前端 Nginx 强制开启 HTTPS，否则 Vaultwarden 拒绝工作（防止明文抓包）。
2. 在后台开启了两步验证（2FA），登录必须输入我手机 Authenticator 上的动态口令。
3. 每天半夜，系统定时把 `./vw-data` 目录下的 `sqlite3` 数据库文件打包加密，推送到云盘。

现在电脑浏览器装上插件，手机装上 App，随时随地自动填充高强度随机密码。数据全握在自己手里，极其安心。
---
title: "容器间连不上？深入剖析 Docker Bridge 网络的 DNS 坑"
date: 2024-12-14T20:50:00+08:00
draft: false
tags: ["Docker", "网络排障", "DNS", "Linux"]
categories: ["服务器运维"]
---

**容器互联的困境**
我手起刀落用 `docker run` 跑了一个 PHP 应用的容器，又用 `docker run` 跑了一个 MySQL 的容器。在配置 PHP 连数据库时，我填了 MySQL 容器的名称 `db_mysql`，结果死活报错：`Unknown MySQL server host 'db_mysql'`。

**踩坑分析**
以前用 `docker-compose` 的时候都是直接写服务名就能通，为啥单跑不行？
去查了 Docker 官方文档才发现：所有直接 `docker run` 起来的容器，默认会被丢进一个叫 `bridge`（桥接）的网络里。而这个默认的桥接网络，**不支持内建的 DNS 解析服务！** 这就意味着它们不能通过名字互访，只能写死内网 IP（比如 172.17.0.2）。

**优雅解决：自定义网络**
千万不要用 `--link` 这个被官方废弃的参数。正确的做法是自己建一个专属的网络：
```bash
# 创建一个叫 my_net 的网络
docker network create my_net

# 把那两个老死不相往来的容器加进这个网
docker network connect my_net php_app
docker network connect my_net db_mysql
```
一旦加入自定义网络，Docker 内置的 DNS 服务就激活了。进 PHP 容器里 `ping db_mysql`，瞬间获取到了内部 IP 并顺利连通。搞懂了 Docker 的底层网络隔离机制，以后部署就不会再抓瞎了。
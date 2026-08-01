---
title: "容器间连不上？深入剖析 Docker Bridge 网络的 DNS 坑"
date: 2024-07-22T20:50:00+08:00
draft: false
tags: ["Docker", "网络排障", "DNS", "Linux"]
categories: ["服务器运维"]
description: "记录一次 Docker 容器间无法通过名称通信的问题排查过程，涉及默认 bridge 网络和自定义网络的 DNS 解析机制。"
---

我手起刀落用 `docker run` 跑了一个 PHP 应用的容器，又用 `docker run` 跑了一个 MySQL 的容器。在配置 PHP 连数据库时，我填了 MySQL 容器的名称 `db_mysql`，结果死活报错：`Unknown MySQL server host 'db_mysql'`。

一开始我以为是 MySQL 容器没启动成功，进去看了下服务是正常的。又以为是防火墙问题，检查了一下端口也是通的。最后才意识到问题出在 Docker 的网络上。

## Docker 默认 bridge 网络的限制

以前用 `docker-compose` 的时候都是直接写服务名就能互相访问，为啥单跑 `docker run` 就不行？

去查了 Docker 官方文档才发现：所有直接 `docker run` 起来的容器，默认会被丢进一个叫 `bridge` 的默认桥接网络里。而这个默认桥接网络有一个很重要的限制：**不支持内建的 DNS 解析服务**。

也就是说，在默认 bridge 网络里，容器之间不能通过容器名互相访问，只能写死内网 IP，比如 `172.17.0.2`。但容器 IP 每次重启可能都会变，写死 IP 显然不现实。

## 验证默认网络的行为

为了确认这一点，我做了个小实验。

启动两个容器：

```bash
docker run -d --name container_a alpine sleep 3600
docker run -d --name container_b alpine sleep 3600
```

进入 container_a 尝试 ping container_b：

```bash
docker exec -it container_a ping container_b
```

结果确实是 `bad address 'container_b'`。

但 ping IP 是可以的：

```bash
docker exec -it container_a ping 172.17.0.3
```

这就验证了默认 bridge 网络确实不支持 DNS。

## 解决方案一：创建自定义网络

正确的做法是创建一个自定义的 bridge 网络。自定义网络默认就支持 DNS 解析。

```bash
docker network create my_net
```

创建容器的时候直接指定网络：

```bash
docker run -d --name php_app --network my_net nginx:alpine
docker run -d --name db_mysql --network my_net mysql:8
```

这样 php_app 里直接 `ping db_mysql` 就能解析到内部 IP。

如果你已经启动了容器，也可以事后把容器加入网络：

```bash
docker network connect my_net php_app
docker network connect my_net db_mysql
```

## 解决方案二：用 Docker Compose

其实最简单的方法还是直接用 Docker Compose。Compose 会自动给项目里的所有服务创建一个默认网络，并且服务名就是 DNS 名。

一个简单的 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    networks:
      - my_network

  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: example
    networks:
      - my_network

networks:
  my_network:
    driver: bridge
```

在这个例子里，`web` 容器里可以直接通过 `db` 访问 MySQL。

这也是我之前用 Compose 没遇到过这个问题的原因，它帮我隐藏了网络配置的复杂性。

## 解决方案三：使用 --link（不推荐）

Docker 早期有一个 `--link` 参数可以实现容器名解析，比如：

```bash
docker run -d --name php_app --link db_mysql:db mysql:8
```

但这个参数已经被官方标记为废弃了，不建议在新项目中使用。未来可能会被移除。

## 排查 DNS 问题的通用思路

遇到容器间网络不通的问题，我一般会按这个顺序排查：

1. **确认容器都在同一个网络里**：

```bash
docker network inspect my_net
```

2. **确认 DNS 是否能解析**：

```bash
docker exec -it 容器名 nslookup 目标容器名
```

3. **确认端口是否监听**：

```bash
docker exec -it 容器名 netstat -tlnp
```

4. **检查防火墙规则**：宿主机或者容器内的 iptables 规则可能拦截了流量。

## 一个相关的坑：自定义 DNS

有时候容器里的 DNS 解析会慢或者解析不到某些域名。这可能是因为 Docker 默认使用宿主机的 DNS 配置。

可以在 `docker run` 时指定 DNS：

```bash
docker run -d --dns 223.5.5.5 --dns 8.8.8.8 nginx:alpine
```

或者在 daemon 配置里全局设置：

```json
{
  "dns": ["223.5.5.5", "8.8.8.8"]
}
```

国内服务器我一般用阿里云的公共 DNS `223.5.5.5`，解析国内域名会快一些。

## 总结

这次的问题虽然不大，但让我对 Docker 网络的理解更深了一层。核心结论：

1. **默认 bridge 网络不支持容器名 DNS 解析**。
2. **自定义 bridge 网络支持 DNS，推荐用这种方式**。
3. **Docker Compose 最省心，适合多容器项目**。
4. **`--link` 已废弃，不要再用了**。

搞懂了 Docker 的底层网络隔离机制，以后部署就不会再抓瞎了。

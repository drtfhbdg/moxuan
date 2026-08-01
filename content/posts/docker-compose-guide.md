---
title: "Docker Compose 部署常用服务总结"
date: 2024-08-08T15:30:00+08:00
draft: false
tags: ["Docker", "Docker Compose", "部署", "运维"]
categories: ["服务器运维"]
description: "总结我用 Docker Compose 部署常见服务的经验和模板，包括博客、数据库、监控和反向代理等场景。"
---

刚开始用 Docker 的时候，我写了一大串 `docker run` 命令，参数又多又乱，后来想改个端口或者加个环境变量，得翻半天历史记录。自从换成 Docker Compose 之后，部署和管理容器变得舒服多了。

Docker Compose 的核心思想是把一个应用的多个服务写在一个 YAML 文件里，一条命令就能启动整个应用栈。这篇文章总结我用 Compose 部署过的一些常用服务，给想入门的人做个参考。

## 为什么用 Docker Compose

相比 `docker run`，Compose 有几个明显优势：

1. **配置集中管理**：所有服务的镜像、端口、环境变量、挂载都写在一个文件里。
2. **一键启停**：`docker-compose up -d` 启动所有服务，`docker-compose down` 停止。
3. **服务自动组网**：同一个 compose 项目里的服务自动在同一个网络里，可以通过服务名互相访问。
4. **便于迁移**：换服务器的时候把 `docker-compose.yml` 和数据目录复制过去就行。

## 基础写法

一个最简单的 `docker-compose.yml` 长这样：

```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    restart: unless-stopped
```

启动：

```bash
docker-compose up -d
```

`-d` 表示后台运行。

## 部署一个静态博客

我的博客前端是 Hugo 生成的静态文件，后端用 Nginx 提供服务。Compose 文件很简单：

```yaml
version: '3.8'

services:
  blog:
    image: nginx:alpine
    container_name: blog
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./public:/usr/share/nginx/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./ssl:/etc/nginx/ssl
    restart: unless-stopped
```

`./public` 是 Hugo 构建出来的静态文件目录。每次更新博客后，重新构建并替换这个目录里的文件即可。

## 部署 WordPress + MySQL

很多老项目还是 WordPress，用 Compose 部署 WordPress 和数据库非常方便：

```yaml
version: '3.8'

services:
  db:
    image: mysql:8.0
    container_name: wp_db
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_password
    volumes:
      - db_data:/var/lib/mysql
    restart: unless-stopped

  wordpress:
    image: wordpress:latest
    container_name: wp_app
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress_password
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp_data:/var/www/html
    depends_on:
      - db
    restart: unless-stopped

volumes:
  db_data:
  wp_data:
```

注意 `WORDPRESS_DB_HOST` 直接写 `db:3306`，因为 Compose 会自动把服务名解析成 IP。

## 部署 Uptime Kuma 监控

Uptime Kuma 是个很好用的监控工具，我自己也在用：

```yaml
version: '3.8'

services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
    restart: unless-stopped
```

启动后访问 `http://服务器IP:3001` 进行初始化配置。

## 部署 Vaultwarden 密码管理器

Vaultwarden 是 Bitwarden 的 Rust 轻量实现，适合个人或小团队自建：

```yaml
version: '3.8'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    environment:
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "false"
    volumes:
      - ./vw-data:/data
    ports:
      - "8080:80"
    restart: unless-stopped
```

`SIGNUPS_ALLOWED: "false"` 表示关闭公开注册，只允许管理员手动邀请用户。自建密码管理器一定要注意安全。

## 部署 Nginx 反向代理

如果一台服务器上跑了多个服务，前面加一个 Nginx 做反向代理是标准做法：

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    restart: unless-stopped

  app1:
    image: myapp1:latest
    container_name: app1
    restart: unless-stopped

  app2:
    image: myapp2:latest
    container_name: app2
    restart: unless-stopped
```

对应的 `nginx.conf` 里可以用服务名做 upstream：

```nginx
server {
    listen 80;
    server_name app1.example.com;

    location / {
        proxy_pass http://app1:8080;
    }
}

server {
    listen 80;
    server_name app2.example.com;

    location / {
        proxy_pass http://app2:8080;
    }
}
```

## 几个使用技巧

### 1. 使用 .env 文件管理敏感信息

不要把密码直接写在 `docker-compose.yml` 里，可以用 `.env` 文件：

```text
MYSQL_ROOT_PASSWORD=your_password
```

然后在 compose 文件里引用：

```yaml
environment:
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

### 2. 合理设置 restart 策略

一般服务用 `unless-stopped`，表示除非手动停止，否则 always 重启。测试环境可以用 `no`。

### 3. 限制容器资源

生产环境建议限制 CPU 和内存，防止某个容器把资源吃光：

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

### 4. 使用 networks 隔离不同项目

如果一台服务器上跑了多个项目，最好给每个项目单独的网络，避免服务名冲突：

```yaml
networks:
  project_a:
    driver: bridge
```

## 常用命令

```bash
# 启动所有服务（后台）
docker-compose up -d

# 查看日志
docker-compose logs -f

# 重启某个服务
docker-compose restart 服务名

# 停止并删除容器
docker-compose down

# 停止并删除容器和数据卷（慎用）
docker-compose down -v

# 拉取最新镜像
docker-compose pull

# 重新构建
docker-compose up -d --build
```

## 总结

Docker Compose 是我目前最喜欢的小型项目部署方式。它不像 Kubernetes 那么重，又比纯 `docker run` 好管理得多。

这篇文章给的几个模板都是我自己实际在用的，你可以根据需求改一改端口、路径和密码就能跑起来。如果刚开始接触 Docker，建议先从一个简单的静态博客或者 Uptime Kuma 入手，熟练之后再挑战多服务组合。

---
title: "VPS 磁盘爆满报警，记录几个极其好用的 Docker 清理命令"
date: 2024-07-05T09:30:00+08:00
draft: false
tags: ["Docker", "磁盘清理", "Linux"]
categories: ["服务器运维"]
description: "分享我清理 Docker 占用磁盘空间的经验，包括悬空镜像、废弃容器、数据卷和构建缓存的清理方法。"
---

早上服务器的监控脚本发来预警，说这台 20G 硬盘的小机器可用空间不足 5% 了。

登上去用 `df -h` 一看，确实快满了。顺着用 `du -sh /*` 往下扒，发现罪魁祸首是 Docker 的目录 `/var/lib/docker`，占了 15G 多。平时瞎折腾拉了一堆镜像，旧容器删了但悬空镜像还在占空间，还有各种构建缓存和数据卷。

这篇文章记录一下我常用的 Docker 清理命令，以及它们分别会删掉什么，避免误删重要数据。

## 先看磁盘占用分布

清理之前，先搞清楚空间到底被什么占了：

```bash
du -sh /var/lib/docker/*
```

更详细一点：

```bash
docker system df
```

这个命令会显示镜像、容器、数据卷、构建缓存各自占了多少空间。我当时的输出大概是这样：

```text
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          45        12        8.2GB     6.1GB (74%)
Containers      8         3         1.2GB     800MB
Local Volumes   23        5         3.5GB     2.8GB
Build Cache     156       0         2.1GB     2.1GB
```

可以看到可清理的空间非常多。

## 清理悬空镜像

什么是悬空镜像？就是那些没有标签、也没有被任何容器引用的镜像。通常出现在反复构建同一个镜像，或者 `docker build` 失败后留下中间层的时候。

清理命令：

```bash
docker image prune
```

这个命令非常安全，只会删除 dangling 镜像，不会影响正在运行的容器。

如果你想连没有被任何容器使用的镜像一起清理，可以加 `-a`：

```bash
docker image prune -a
```

**注意**：`-a` 会删掉所有没有容器在用的镜像。如果你有一些镜像只是暂时没跑，但之后还要用，就别加 `-a`。

## 清理停止的容器

有时候我们跑完一个容器就忘了删，用 `docker ps -a` 能看到一堆 `Exited` 状态的容器。这些容器也会占用磁盘空间，尤其是如果它们写了很多日志或者临时文件的话。

清理所有停止的容器：

```bash
docker container prune
```

执行之前建议先看一下有哪些会被清理：

```bash
docker ps -a --filter status=exited
```

如果你确定这些停止的容器都没用了，再执行 prune。

## 清理废弃数据卷

数据卷是 Docker 里最容易被遗忘的空间杀手。很多容器删除的时候没有用 `-v` 参数，对应的数据卷就留在了系统里，越积越多。

查看所有数据卷：

```bash
docker volume ls
```

清理没有被任何容器使用的数据卷：

```bash
docker volume prune
```

**重要提示**：数据卷里可能存着你重要的数据库文件、配置文件。执行之前一定要确认这些数据卷确实没用了。

我一般会先 inspect 一下数据卷：

```bash
docker volume inspect 卷名
```

看看挂载点和标签，确认不是重要数据再删。

## 清理构建缓存

如果你经常用 `docker build`，构建缓存会占用不少空间。Docker 18.09 之后引入了 BuildKit，缓存机制更复杂，但也更容易堆积。

清理所有构建缓存：

```bash
docker builder prune
```

或者更狠一点，全部清理：

```bash
docker buildx prune -f
```

清理构建缓存一般比较安全，下次构建会重新拉取基础镜像和生成中间层，只是会多花点时间。

## 一键清理所有

如果你已经很清楚自己在干什么，可以用 `docker system prune` 一键清理：

```bash
docker system prune
```

这个命令会清理：

- 所有停止的容器
- 所有悬空网络
- 所有悬空镜像
- 所有构建缓存

如果想连没有使用的镜像和数据卷也一起清理：

```bash
docker system prune -a --volumes
```

**警告**：这个命令杀伤力很大，执行前一定要想清楚。`-a` 会删掉未使用的镜像，`--volumes` 会删掉未使用的数据卷。

我那次就是直接用了 `docker system prune -a --volumes`，一下腾出 8G 空间，舒服了。

## 限制日志大小

清理完空间之后，还要防止以后再次快速占满。Docker 容器的日志默认是无限制增长的，一个跑久了的容器日志文件可能有几个 G。

可以在 daemon 配置里限制日志大小。创建或编辑 `/etc/docker/daemon.json`：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

然后重启 Docker：

```bash
systemctl restart docker
```

这样每个容器的日志最多保留 3 个 10M 的文件，超过就自动轮转。

## 定期自动清理

为了避免手动清理，我加了一个每周自动清理的 cron 任务：

```bash
0 3 * * 0 /usr/bin/docker system prune -f > /dev/null 2>&1
```

`-f` 表示不需要确认。注意我这里没有加 `-a` 和 `--volumes`，因为自动任务里用太激进的参数有风险。每周清理一下停止的容器和悬空镜像就够了。

## 总结

Docker 清理命令从温和到激进：

- `docker image prune`：清理悬空镜像，最安全
- `docker container prune`：清理停止的容器
- `docker volume prune`：清理未使用的数据卷，要小心
- `docker builder prune`：清理构建缓存
- `docker system prune -a --volumes`：一键全清，杀伤力最大

建议大家先用 `docker system df` 看看空间分布，然后按需清理。不要一上来就 `--volumes`，万一删掉重要数据就亏大了。

最后提醒一句：清理之前最好做个快照备份，尤其是小 VPS 上跑了数据库等重要服务的时候。

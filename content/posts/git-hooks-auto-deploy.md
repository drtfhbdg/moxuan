---
title: "告别手动传文件，利用 Git Hooks 实现代码推送到服务器的全自动部署"
date: 2024-11-10T14:50:00+08:00
draft: false
tags: ["Git", "自动化部署", "运维", "持续集成"]
categories: ["架构部署"]
---

**告别 FTP 时代**
以前修改博客的前端代码或者自己的小项目，总是在本地改完，用 FTP 软件拖到服务器，极其繁琐，且版本经常搞混。
稍微研究了一下 Git 底层的钩子逻辑（Git Hooks），花半小时搞定了一套极简的自动化部署流水线。

**原理与配置**
在我的云服务器上，我没有选择庞大的 Jenkins，而是直接初始化了一个“裸仓库”（Bare Repository）：
```bash
git init --bare /home/git/myproject.git
```
然后跑到仓库的 `hooks` 目录下，新建了一个 `post-receive` 脚本。这个脚本会在我每次把代码 `push` 到服务器后自动触发。

**核心同步脚本**
```bash
#!/bin/bash
# 定义工作区目录（前端访问的 Nginx 目录）
TARGET="/var/www/html/myproject"
GIT_DIR="/home/git/myproject.git"

echo "==== 正在接收推送并自动部署 ===="
# 强制检出最新的代码到 Nginx 目录下
git --work-tree=$TARGET --git-dir=$GIT_DIR checkout -f
echo "==== 部署完成 ===="
```
赋予脚本执行权限 `chmod +x post-receive`。

最后在本地电脑把服务器加为远程分支：
`git remote add prod root@我的IP:/home/git/myproject.git`。
以后只要在本地敲下 `git push prod master`，服务器立刻自己更新页面。效率提升 1000%。
---
title: "从零开始用 Hugo 搭一个干净的技术博客"
date: 2024-02-15T20:30:00+08:00
draft: false
tags: ["Hugo", "博客搭建", "静态博客"]
categories: ["博客搭建"]
description: "记录我抛弃 WordPress 和 Hexo，最终用 Hugo 重新搭建个人博客的完整过程，包括主题选择、配置踩坑和部署上线。"
---

说实话，我之前也折腾过不少博客方案。最早是 WordPress，功能确实强，插件也多，但架不住后台太臃肿了，我那台 1 核 1G 的小 VPS 跑起来经常内存报警。后来换过 Hexo，静态生成倒是轻快了，但 node_modules 懂得都懂，换个电脑环境要配半天，而且构建速度在大文章多之后也开始变慢。

兜兜转转，最后选了 Hugo。就一个字：快。整个站点几百篇文章，构建时间按毫秒算，本地预览几乎是秒开。而且它用 Go 写的，就一个二进制文件，部署起来极其省心。

这篇文章就记录一下我从零开始用 Hugo 搭建这个博客的全过程，给同样想拥有一个干净技术博客的人一个参考。

## 为什么最终选了 Hugo

市面上静态博客生成器很多，我简单列一下我当时考虑的几种：

- **Hexo**：主题多，社区成熟，中文资料丰富。但基于 Node.js，依赖多，构建速度一般。
- **Jekyll**：老牌工具，GitHub Pages 原生支持。但 Ruby 环境在国内配置起来比较麻烦。
- **Gatsby**：功能强大，但太重了，更像一个前端项目而不是博客工具。
- **Hugo**：单二进制、构建飞快、主题够用、配置简单。

我这个人比较懒，不想把太多时间花在维护工具链上。Hugo 的哲学就很对我胃口：下载一个文件，解压，运行，完事。

## 安装 Hugo

Hugo 的安装方式很多，我推荐直接下载官方预编译好的二进制文件，最不容易出错。

去 GitHub Release 页面下载对应系统的压缩包，解压后把 `hugo` 可执行文件放到系统 PATH 里就行。比如在 Linux 下可以这么做：

```bash
# 下载 Linux 64 位版本（版本号自己去官网看最新的）
wget https://github.com/gohugoio/hugo/releases/download/v0.123.0/hugo_extended_0.123.0_linux-amd64.tar.gz

# 解压
tar -zxvf hugo_extended_0.123.0_linux-amd64.tar.gz

# 移动到 /usr/local/bin 方便全局调用
sudo mv hugo /usr/local/bin/

# 验证
hugo version
```

这里有个坑要注意：很多主题需要 Hugo 的 Extended 版本，因为要用到 SCSS/SASS 编译。如果你下载的是普通版，后续启用某些主题会报错。我一开始就下错了，浪费半小时排查，建议直接下 Extended 版。

macOS 用户用 Homebrew 更方便：

```bash
brew install hugo
```

Windows 用户要么用 Scoop，要么去官网下载 exe 手动配置环境变量。

## 创建站点

安装好之后，创建站点只需要一行命令：

```bash
hugo new site my-blog
cd my-blog
```

执行完你会看到生成了这样的目录结构：

```
my-blog/
├── archetypes/        # 内容模板
├── assets/            # 需要 Hugo 处理的资源
├── content/           # 文章内容，核心目录
├── data/              # 数据文件
├── layouts/           # HTML 模板
├── static/            # 静态文件，直接复制到输出目录
├── themes/            # 主题目录
└── hugo.toml          # 站点配置文件
```

一开始看不懂没关系，大多数目录你都不会立刻用到。核心就两个：`content/` 放文章，`config` 文件改站点设置。

## 选择主题

Hugo 官方主题站有几百个主题，但质量参差不齐。我当初挑主题挑了整整两天，最后选了 PaperMod。原因挺简单的：

1. 界面干净，没有花里胡哨的动画。
2. 适配了移动端，阅读体验不错。
3. 功能全：搜索、归档、标签、暗色模式、代码复制、阅读时间这些都有。
4. 配置文档虽然不算特别详细，但看示例站点基本能配出来。

安装主题一般用 git submodule：

```bash
git init
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
```

然后在 `hugo.toml` 里加上：

```toml
theme = 'PaperMod'
```

## 第一篇内容

Hugo 提供了很方便的 new content 命令：

```bash
hugo new content posts/hello-world.md
```

打开生成的文件，你会看到 front matter：

```yaml
---
title: "Hello World"
date: 2024-02-15T20:30:00+08:00
draft: true
---
```

把 `draft: true` 改成 `draft: false` 就表示发布。写文章用 Markdown，Hugo 用的是 Goldmark 渲染器，支持标准的 Markdown 语法，也支持代码高亮。

这里有一个我踩过的坑：Hugo 的代码块默认语言识别有时候不太准，建议每段代码块都显式标注语言，比如：

```markdown
```bash
echo "hello"
```
```

## 本地预览

写文章的时候肯定要实时预览，Hugo 的本地服务器支持热重载：

```bash
hugo server -D
```

`-D` 参数表示也渲染草稿。打开浏览器访问 `http://localhost:1313` 就能看到效果。你修改文章保存后，浏览器会自动刷新，非常方便。

## 部署上线

静态博客的好处就是部署选择特别多。我用的是 GitHub Pages + GitHub Actions，免费还省心。

基本思路是：

1. 源码推送到 GitHub 仓库。
2. 配置 GitHub Actions 工作流，每次 push 自动运行 `hugo` 构建。
3. 构建产物推送到 `gh-pages` 分支。
4. GitHub Pages 从这个分支部署。

我的 `.github/workflows/hugo.yml` 大概是这个样子：

```yaml
name: Deploy Hugo site to Pages

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: '0.123.0'
          extended: true
      - name: Build
        run: hugo --minify
      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
```

注意 `submodules: recursive` 一定要加，不然主题代码拉不下来，构建会直接报错。这个坑我踩过两次。

## 域名和 HTTPS

GitHub Pages 默认给你一个 `用户名.github.io` 的域名，如果想用自己的域名，可以在仓库设置里配置 Custom domain，然后在 DNS 服务商那里加一个 CNAME 记录指向 GitHub Pages。

我的域名是在 Cloudflare 管理的，CNAME 配置好之后，GitHub 会自动申请 Let's Encrypt 证书，全程不用操心。

## 总结一下

Hugo 整个搭建流程其实不复杂：

1. 下载 Hugo Extended 版
2. 用 `hugo new site` 创建站点
3. 选一个主题，我用的是 PaperMod
4. 用 `hugo new content` 写文章
5. 本地用 `hugo server -D` 预览
6. 推到 GitHub，用 Actions 自动部署

比起之前用 WordPress 的时候，我现在几乎不用管服务器维护这件事。文章写完了 push 一下，几秒钟后就自动上线了。对于一个只想安安静静写点东西的人来说，Hugo 真的挺合适的。

如果你也打算搭一个个人博客，我的建议是不用太纠结主题，先跑起来再说。很多时候我们卡在"选主题"这一步就放弃了，其实内容才是最重要的。

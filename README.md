# Moxuan's Blog

我的个人博客源码，基于 [Hugo](https://gohugo.io/) + [PaperMod](https://github.com/adityatelange/hugo-PaperMod) 主题，托管在 GitHub Pages。

线上地址：<https://moxuan.xin/>

主要写 Linux 运维、Web 开发和服务器踩坑的笔记，内容大多来自自己折腾 VPS 的过程：Nginx、Docker、MySQL、Cloudflare、自建服务这些。

## 本地运行

需要 Hugo **extended** 版本（主题的 SCSS 要用到），目前线上构建用的是 0.154.3。

```bash
git clone --recurse-submodules https://github.com/drtfhbdg/moxuan.git
cd moxuan
hugo server -D
```

主题是 git submodule，克隆时忘了带 `--recurse-submodules` 的话补一下：

```bash
git submodule update --init --recursive
```

然后访问 http://localhost:1313 。`-D` 表示把草稿也渲染出来。

## 写文章

```bash
hugo new content posts/my-new-post.md
```

frontmatter 大致长这样：

```yaml
---
title: "文章标题"
date: 2024-03-10T14:20:00+08:00
draft: false
tags: ["Hugo", "SEO"]
categories: ["博客搭建"]
description: "会用在列表摘要和搜索引擎结果里，建议手写。"
---
```

`draft: true` 的文章不会出现在正式构建里（`buildDrafts: false`）。

## 目录结构

```
content/posts/            文章
content/about.md          关于页
content/archives.md       归档页
assets/css/extended/      自定义样式，PaperMod 会自动合并进 stylesheet
layouts/partials/         覆盖主题的局部模板
layouts/_default/         覆盖主题的页面模板
static/                   直接拷到站点根目录的文件（favicon、光标图标等）
scripts/                  辅助脚本
hugo.yaml                 站点配置，注释写得比较细
themes/PaperMod/          主题，git submodule
```

## 样式定制

样式都放在 `assets/css/extended/`，PaperMod 会自动把这个目录下的 CSS 合并进最终的 stylesheet，不用改主题本身：

| 文件 | 作用 |
| --- | --- |
| `theme-vars-override.css` | 覆盖主题的颜色变量，亮色/暗色两套 |
| `blank.css` | 导航、文章内容、分页、代码块这些组件的样式 |
| `chroma-styles-overrides.css` | 代码高亮配色 |
| `scroll-bar-overrides.css` | 滚动条 |
| `footer-overrides.css` | 页脚 |

改颜色优先动 `theme-vars-override.css` 里的变量。有一点需要注意：`--accent` 存的是 `#4f46e5` 这种十六进制值，不能直接塞进 `rgba()`。要带透明度的话用旁边那组 `--accent-rgb` / `--theme-rgb` 变量，它们存的是 `79, 70, 229` 这样的三元组。

## favicon

各尺寸图标由脚本从一张源图生成，不要手改 `static/` 下的那几个 PNG：

```powershell
pwsh scripts/resize-favicon.ps1
```

源图是 `assets/favicon-source.png`（1024x1024）。换图之后重跑脚本，会生成 `favicon.png`、`favicon-16x16.png`、`favicon-32x32.png`、`apple-touch-icon.png` 四个文件。

## 评论

用的是 [giscus](https://giscus.app/)，默认关着。要开启的话，把 `hugo.yaml` 里 `params.giscus` 那段注释解开填上自己的仓库信息，再把 `params.comments` 改成 `true`。

`layouts/partials/comments.html` 里有个守卫，giscus 配置不完整时不会渲染评论区，所以只改 `comments: true` 而不填配置是没有效果的，不会留下一个空框。

## 部署

推到 `main` 分支就会触发 [.github/workflows/hugo.yaml](.github/workflows/hugo.yaml)，GitHub Actions 构建完自动发布到 GitHub Pages。构建用的是 `hugo --gc --minify`，`public/` 不进版本库。

## License

文章内容版权归我所有（©2023-2026 moxuan）。主题 PaperMod 遵循其自身的 MIT 许可。

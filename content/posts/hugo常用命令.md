+++

date = '2026-01-08T10:18:50+08:00'
draft = true
title = 'hugo常用命令'

categories = ["通用技术"] 

tags = ["博客搭建", "Bilibili"] 

+++







#### 1. 基础项目操作

##### 创建新 Hugo 站点

```css
 # 创建名为 my-blog 的新站点（会生成一个同名文件夹

 hugo new site my-blog 
```



**用途**：初始化一个全新的 Hugo 项目，生成基础目录结构（content、themes、config 等）。

**注意**：执行后需要进入项目目录（`cd my-blog`）再进行后续操作。

#####  安装主题（以 Anake 为例） 

```css
# 进入站点目录后，克隆主题到 themes 文件夹 
git clone https://github.com/theNewDynamic/gohugo-theme-ananke.git themes/ananke

（可选）将主题配置添加到站点配置文件

 echo "theme = 'ananke'" >> config.toml 
```

**用途**：为站点添加主题，是 Hugo 站点可视化的基础。

**提示**：也可以手动下载主题压缩包解压到 themes 目录。

#### 2.文章 / 内容操作（核心） 

#####  创建新文章（最常用） 

```css
# 创建一篇名为 "my-first-post" 的文章，默认格式为 markdown

hugo new posts/my-first-post.md

# 自定义文章标题（推荐）

hugo new posts/2024-01-07-my-first-post.md

# 创建非 posts 目录的内容（比如 pages 页面）

hugo new about.md
```

**核心说明**：

生成的文件位于 `content/` 目录下（如 `content/posts/my-first-post.md`）。

新文章默认包含 Front Matter（标题、日期、草稿状态等），且默认标记为 `draft: true`（草稿状态）。

文件名建议用「日期 - 标题」格式，便于管理和 SEO。

#####  发布草稿文章 

```
# 方式1：直接编辑文章的 Front Matter，将 draft: true 改为 draft: false

# 方式2：运行 Hugo 时强制渲染草稿

hugo server -D  # -D 是 --buildDrafts 的缩写，渲染草稿内容
```

##### 3.本地预览 / 开发 

 启动本地开发服务器 

```css
# 基础启动（不渲染草稿、未来文章）

hugo server

# 常用启动方式（渲染草稿+实时刷新+显示详细日志）

hugo server -D --watch --verbose
```

```css
# 1. 追踪所有本地修改的文件

git add .

# 2. 提交修改并写一句说明（替换引号里的内容）

git commit -m "更新Hugo内容/样式"

# 3. 推送到GitHub远程仓库（默认分支是main，按自己的分支名改）

git push origin main
```


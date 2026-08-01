---
title: "PaperMod 主题二次开发与小改造记录"
date: 2024-04-05T21:00:00+08:00
draft: false
tags: ["Hugo", "PaperMod", "主题定制", "前端"]
categories: ["博客搭建"]
description: "记录我对 Hugo PaperMod 主题做的一些小改造，包括首页信息、页脚备案、代码复制按钮和暗色模式的调整。"
---

PaperMod 这个主题用的人挺多的，但默认配置出来的页面，说实话有点"千篇一律"。我看了几个同样用这个主题的博客，首页长得都差不多，要不是域名不同，差点以为是同一个站。

所以我就想着给主题做一些小改造，让它看起来更像"我的博客"，而不是"PaperMod 默认皮肤"。这篇记录一下我改过的几个地方，都不复杂，复制粘贴就能用。

## 改造前的准备

PaperMod 主题默认是通过 git submodule 引入的，直接改 `themes/PaperMod` 里的文件不太合适，因为下次更新主题会冲突。正确做法是使用 Hugo 的模板覆盖机制：

只要在项目根目录的 `layouts/` 下创建和主题里同名的文件，Hugo 会优先使用你项目里的版本。这样主题更新了也不会影响你的修改。

比如我想覆盖主题的 `layouts/partials/footer.html`，就在项目里新建 `layouts/partials/footer.html`，Hugo 会自动用我项目里的这个文件。

## 1. 自定义首页 profile

PaperMod 默认首页会显示一个标题和一段介绍文字，通过 `params.homeInfoParams` 配置。但默认样式比较朴素，我改了一下让它更紧凑：

```yaml
params:
  homeInfoParams:
    Title: "Moxuan's Blog"
    Content: "这里记录我折腾服务器、写代码和踩坑的日常。文章不一定对，但一定真实。"
```

如果你想更进一步，可以创建 `layouts/partials/home_info.html` 完全自定义首页的这块区域。我当时加了一个简单的个人介绍和最近文章列表，看起来更像个真正的首页。

## 2. 页脚加备案号

国内网站底部加备案号几乎是必须的，PaperMod 默认页脚只有版权信息。我通过覆盖 `layouts/partials/footer.html` 来加上备案号。

我的页脚文件大致内容：

```html
<footer class="footer">
    <span>&copy; 2024 <a href="{{ "" | absURL }}">Moxuan</a></span>
    <span>
        Powered by
        <a href="https://gohugo.io/" rel="noopener noreferrer" target="_blank">Hugo</a>
        &
        <a href="https://github.com/adityatelange/hugo-PaperMod/" rel="noopener" target="_blank">PaperMod</a>
    </span>
    <span>
        <a href="https://beian.miit.gov.cn/" target="_blank">苏ICP备XXXXXXXX号-1</a>
    </span>
</footer>
```

然后用一点 CSS 把三行居中对齐：

```css
.footer {
    text-align: center;
    font-size: 14px;
    color: var(--secondary);
}
.footer span {
    display: block;
    margin: 4px 0;
}
```

备案号记得换成你自己的，不然被查到很麻烦。

## 3. 调整代码块的复制按钮

PaperMod 自带代码复制按钮，但默认位置我有点不习惯。我想让它更明显一点，就去改了 CSS。

创建 `assets/css/extended/blank.css`（PaperMod 会自动加载这个目录下的 CSS），然后写：

```css
.copy-code {
    background: var(--code-bg);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 12px;
    cursor: pointer;
}

.copy-code:hover {
    background: var(--primary);
    color: var(--theme);
}
```

这里用到了 PaperMod 定义的 CSS 变量，比如 `--code-bg` 和 `--primary`，所以能自动适配暗色模式，不用写两套样式。

## 4. 让暗色模式默认开启

PaperMod 默认是亮色模式，需要用户手动点切换按钮才能变成暗色。我观察了一下，现在很多技术博客默认就是暗色，看起来更有"技术感"一点。

把默认主题改成暗色很简单，在 `hugo.yaml` 里改：

```yaml
params:
  defaultTheme: dark
```

如果你想尊重用户的系统设置，可以改成 `auto`，这样会根据系统主题自动切换。

不过要注意，改成 dark 之后，有些自己加的自定义元素可能颜色会不对劲，最好在暗色和亮色下都检查一遍。

## 5. 给文章加阅读进度条

这个改动稍微麻烦一点，但效果还不错。我在文章页面顶部加了一个细长的进度条，随着滚动慢慢变长。

实现思路是用 JavaScript 监听滚动事件，计算滚动百分比，然后调整一个 div 的宽度。

在 `layouts/partials/extend_head.html` 里加样式：

```html
<style>
#reading-progress {
    position: fixed;
    top: 0;
    left: 0;
    height: 3px;
    background: var(--primary);
    width: 0%;
    z-index: 1000;
    transition: width 0.1s;
}
</style>
```

在 `layouts/partials/extend_footer.html` 里加脚本：

```html
<script>
document.addEventListener('scroll', function() {
    var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
    var scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    var progress = (scrollTop / scrollHeight) * 100;
    document.getElementById('reading-progress').style.width = progress + '%';
});
</script>
```

然后在 `layouts/partials/extend_head.html` 里再把这个进度条 div 加进去：

```html
<div id="reading-progress"></div>
```

这样每篇文章顶部都会有一个细细的进度条。虽然不是什么刚需，但能增加一点精致感。

## 6. 自定义 404 页面

PaperMod 的 404 页面比较简陋，我换成了一个带搜索框的 404 页面。读者访问到不存在的页面时，可以直接搜索想找的内容。

创建 `layouts/404.html`：

```html
{{ define "main" }}
<div class="not-found">
    <h1>404</h1>
    <p>这个页面不存在，可能被我不小心删掉了。</p>
    <p>你可以试试搜索：</p>
    <input type="text" id="search-input" placeholder="输入关键词..." autofocus>
    <div id="search-results"></div>
</div>
{{ end }}
```

具体搜索功能要配合 Fuse.js 实现，代码比较长，这里就不展开了。核心思路是用主题自带的搜索 JSON 数据，在 404 页面复用搜索逻辑。

## 7. 修改文章列表的摘要长度

PaperMod 首页文章列表会显示摘要，但默认长度有点短，我觉得显示 150 个字符左右比较合适。

在 `hugo.yaml` 里配置：

```yaml
params:
  ShowFullTextinRSS: false
```

如果你想更精细地控制摘要，可以在文章 front matter 里加 `summary` 字段，或者使用 `<!--more-->` 手动截取摘要。

我比较喜欢手动控制，所以在每篇文章合适的位置插入 `<!--more-->`，这样首页显示的摘要就是我想让读者看到的那部分。

## 8. 加一个小改动：文章最后显示版权声明

这个看个人喜好，我在每篇文章底部加了一个简单的版权声明，防止别人直接全文复制走。

创建 `layouts/partials/post_copyright.html`：

```html
<div class="post-copyright">
    <p>本文作者：Moxuan</p>
    <p>本文链接：<a href="{{ .Permalink }}">{{ .Permalink }}</a></p>
    <p>转载请注明出处。</p>
</div>
```

然后在 `layouts/_default/single.html` 里合适位置引用：

```html
{{ partial "post_copyright.html" . }}
```

## 改造完的感受

经过这么一通小改动，博客看起来已经不太像"PaperMod 默认皮肤"了。虽然改动都不大，但累积起来的效果还是挺明显的。

最重要的是，这些改造都是基于模板覆盖和自定义 CSS，主题以后更新不会影响我的修改。维护起来很轻松。

如果你也用 PaperMod，建议不要一上来就大改。先从小地方开始，慢慢调整到自己喜欢的样子。主题只是壳，内容才是内核。

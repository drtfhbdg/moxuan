---
title: "Hugo 博客 SEO 与性能调优实践"
date: 2024-03-10T14:20:00+08:00
draft: false
tags: ["Hugo", "SEO", "性能优化", "静态博客"]
categories: ["博客搭建"]
description: "分享我给自己的 Hugo 博客做 SEO 和性能优化的一些经验，包括站点地图、Open Graph、加载速度和搜索引擎收录。"
---

博客搭好之后，我就开始研究怎么让文章更容易被搜到。虽然说写博客主要是给自己看，但说实话，谁不希望自己辛辛苦苦写的文章能被人通过搜索引擎找到呢？更何况有些技术笔记确实能帮到别人。

这篇就记录一下我给 Hugo 博客做 SEO 和性能优化时做的一些事情。都不是什么高深技术，但确实有效。

## 1. 站点标题和描述要写好

Hugo 的配置文件里，`title` 和 `params.description` 会直接影响搜索引擎结果页的展示。别小看这一行字，很多人搜到你博客，第一眼看到的就是这个。

我的 `hugo.yaml` 里大概是这么配的：

```yaml
baseURL: "https://blog.moxuan.xin/"
title: "Moxuan's Blog"

params:
  description: "一个记录技术踩坑与个人学习的博客，主要分享 Linux 运维、Web 开发和服务器管理经验。"
  author: "Moxuan"
```

`title` 不用太长，简洁有力就行。`description` 建议控制在 80 到 120 字之间，太长搜索引擎会截断。

## 2. 每篇文章的 front matter 要规范

Hugo 的 PaperMod 主题会读取 front matter 来生成 Open Graph 和 Twitter Cards。如果你不加这些，分享到社交平台的时候就只有光秃秃一个链接，很丑。

我现在的 front matter 模板大概长这样：

```yaml
---
title: "文章标题"
date: 2024-03-10T14:20:00+08:00
draft: false
tags: ["Linux", "Nginx"]
categories: ["服务器运维"]
description: "用一句话概括这篇文章讲了什么，控制在 100 字以内。"
---
```

`description` 字段很重要，它会被用作：

- 搜索引擎结果页的摘要
- Open Graph 的 `og:description`
- 首页文章列表的摘要显示

如果你的主题支持 `cover`，还可以给文章配一张封面图，分享到社交平台效果会更好。

## 3. 开启自动生成站点地图

Hugo 默认就会生成 `sitemap.xml`，但最好检查一下配置，确认没有被关掉。站点地图是告诉搜索引擎你有哪些页面的最有效方式。

你可以在 `hugo.yaml` 里这样配置：

```yaml
sitemap:
  changefreq: "weekly"
  priority: 0.5
  filename: "sitemap.xml"
```

生成之后，访问 `https://你的域名/sitemap.xml` 应该能看到所有页面的列表。

然后我还做了两件事：

1. 在百度资源平台和 Google Search Console 都提交了站点地图。
2. 在 `robots.txt` 里允许搜索引擎抓取，并指向 sitemap。

Hugo 配置 `enableRobotsTXT: true` 之后会自动生成 `robots.txt`，默认是允许全部抓取的。如果你想自定义，可以在 `layouts/robots.txt` 里写自己的版本：

```text
User-agent: *
Allow: /

Sitemap: https://blog.moxuan.xin/sitemap.xml
```

## 4. URL 结构要干净

Hugo 默认的文章 URL 是 `https://域名/posts/文章标题/`，这种结构已经挺好了。但我个人更喜欢把日期加进去，变成 `https://域名/posts/2024/03/文章标题/` 这种层级。

配置方式是在 `hugo.yaml` 里加 permalink：

```yaml
permalinks:
  posts: "/posts/:year/:month/:slug/"
```

这样 URL 会更清晰，读者从地址栏就能大致看出这是什么时候的文章。而且搜索引擎一般也比较喜欢有语义的 URL。

不过要注意，改了 permalink 之后旧的 URL 会 404。如果是已经上线的博客，记得做 301 重定向。我是因为新站，所以无所谓。

## 5. 图片优化

我之前写文章特别喜欢直接丢高清截图，一张图一两兆，结果首页加载慢得离谱。后来狠狠优化了一波：

**压缩图片**

用 TinyPNG 或者 ImageMagick 把图片压缩一下，一般能减少 60% 到 80% 的体积。我本地用 ImageMagick 批量压缩：

```bash
magick input.png -quality 85 output.jpg
```

**延迟加载**

PaperMod 主题本身对图片有懒加载支持，但如果你是自己写主题，记得给 `img` 标签加上 `loading="lazy"`。

**使用 WebP**

现在主流浏览器都支持 WebP 了，同样的视觉质量下体积比 JPEG 小很多。Hugo 有图片处理功能，可以在模板里自动转换格式，不过配置起来稍微麻烦一点，我目前还没完全搞，先用压缩后的 JPEG 顶着。

## 6. 代码高亮不要拖慢页面

Hugo 自带的代码高亮是用 Chroma，默认配置下可能会给每行代码都生成行号，导致首页摘要里全是数字，很丑。

我的高亮配置是这样的：

```yaml
markup:
  goldmark:
    renderer:
      unsafe: true
  highlight:
    codeFences: true
    noClasses: false
    lineNos: true
    lineNumbersInTable: false
```

关键点是把 `lineNumbersInTable` 设为 `false`，这样就不会在摘要里显示一堆行号。另外 `noClasses: false` 表示用 CSS 类来高亮，而不是内联样式，可以让生成的 HTML 更小。

## 7. 启用搜索功能

PaperMod 主题支持 Fuse.js 搜索，配置好之后读者可以通过搜索框快速找到文章。这对 SEO 本身没直接影响，但能降低跳出率，间接对搜索引擎友好。

配置方法是在 `hugo.yaml` 里加上：

```yaml
outputs:
  home:
    - HTML
    - RSS
    - JSON
```

主题会自动读取首页输出的 JSON 来构建搜索索引。记得改了配置之后要重新生成站点，不然搜索索引不会更新。

## 8. 生成 RSS

虽然现在用 RSS 的人少了，但还是有一些老读者喜欢用阅读器订阅博客。Hugo 默认就生成 RSS，URL 是 `/index.xml`。

我额外在页脚加了一个 RSS 订阅按钮，方便需要的人订阅。配置方法参考主题的 `socialIcons`：

```yaml
params:
  socialIcons:
    - name: rss
      url: "index.xml"
```

## 9. 性能测试

优化完之后，我会用几个工具测一下效果：

- **Lighthouse**：Chrome 自带的性能评分工具，重点关注 Performance 和 SEO 分数。
- **PageSpeed Insights**：Google 官方的在线测速工具，会给出具体优化建议。
- **GTmetrix**：也是在线测速，可以看瀑布流分析具体哪个资源慢。

我优化前首页 Lighthouse 性能分数大概是 60 多分，优化后能到 90 分以上。主要的提升来自图片压缩和代码高亮配置的改动。

## 10. 内容本身最重要

最后想说一句，所有 SEO 技巧都是锦上添花。如果你文章质量不行，再好的 SEO 也留不住读者。相反，如果你持续输出有价值的内容，即使不做太多优化，慢慢也会被搜索引擎收录和推荐。

我的策略是：每篇文章都认真写，标题准确，描述清楚，代码可复现。剩下的交给时间。

## 总结

这次优化主要做了这些事情：

- 写好站点标题和描述
- 规范每篇文章的 front matter
- 生成并提交 sitemap
- 优化 URL 结构
- 压缩图片，启用懒加载
- 调整代码高亮配置
- 开启站内搜索
- 保留 RSS 订阅
- 用 Lighthouse 等工具验证效果

如果你也在用 Hugo，可以照着这个清单检查一下自己的博客，应该能有不少提升。

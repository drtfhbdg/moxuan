+++
date = '2024-11-11T18:54:34+08:00'
draft = false
title = 'Github page配置自定义域名'

tags = ["博客搭建"]



+++

## **✅ 第 1步 在 Hugo 项目的 `static` 目录里创建一个 `CNAME` 文件**

 内容只有一行：`blog.moxuan.de`
 然后重新 `hugo` 构建并 `git push` 

一般是你之前运行过：

```
hugo server
```

的那个目录，例如（示例）：

```
D:\hugo\mingyue\
```

你可以看到里面有这些目录之一：

```
archetypes
content
layouts
static   ← 我们要用的
themes
config.toml / hugo.yaml
```

------

### ✅ 第 2 步：在 `static` 目录创建 CNAME 文件

#### 方法一（最稳，推荐）

1. 进入：

   ```
   D:\hugo\mingyue\static\
   ```

2. **右键 → 新建 → 文本文档**

3. 重命名为：

   ```
   CNAME
   ```

   ⚠️ 一定要 **没有 `.txt` 后缀**

> 如果你看不到后缀：
>  文件资源管理器 → 查看 → 勾选「文件扩展名」

------

### ✅ 第 3 步：编辑 CNAME 内容

用记事本打开 `CNAME`，内容 **只写这一行**：

```
blog.moxuan.de
```

- 不要空行
- 不要 http / https
- 不要多余空格

保存。

------

## 三、重新生成 Hugo 静态文件

回到 Hugo 项目根目录，在终端执行：

```
hugo
```

执行完成后，检查：

```HTML
public/CNAME
```

👉 **这个文件必须存在**
 👉 内容也应该是 `blog.moxuan.de`

如果这里有，说明 Hugo 已经帮你正确拷贝了。

------

## 四、把 CNAME 推送到 GitHub

### 1️⃣ 查看 git 状态

```
git status
```

你应该能看到类似：

```
new file: static/CNAME
new file: public/CNAME
```

------

### 2️⃣ 提交并推送

```
git add .
git commit -m "Add CNAME for custom domain"
git push
```

------

## 五、回到 GitHub Pages 重新绑定

1. 打开：

   ```
   仓库 → Settings → Pages
   ```

2. 如果有旧的域名 → 点 **Remove**

3. 重新输入：

   ```
   blog.moxuan.de
   ```

4. 点击 **Save**

5. 等 2～10 分钟，点 **Check again**

------

## 六、成功的标志（非常重要）

你会看到：

- ❌ 红色 `DNS check unsuccessful` 消失
- ✅ 出现 `DNS check successful`
- ✅ **Enforce HTTPS** 可以勾选
+++
date = '2023-12-01T18:54:34+08:00'
draft = false
title = 'Git常用命令'

tags = ["博客搭建"] 

+++

## 一、基础

### 1️⃣ 初始化仓库

```css
git init
```

👉 把当前文件夹变成 Git 仓库（只用一次）

------

### 2️⃣ 查看状态

```css
git status
```

👉 看：

- 哪些文件被修改了
- 哪些还没提交

------

### 3️⃣ 添加到暂存区

```css
git add 文件名
```

或添加全部：

```css
git add .
```

------

### 4️⃣ 提交代码

```css
git commit -m "提交说明"
```

例：

```css
git commit -m "更新博客文章"
```

⚠️ 提示：
 出现

```css
nothing to commit, working tree clean
```

说明**没有新改动**

------

### 5️⃣ 查看提交记录

```css
git log
```

简洁版：

```css
git log --oneline
```

------

## 二、和 GitHub 远程仓库相关

### 6️⃣ 绑定远程仓库

```css
git remote add origin 仓库地址
```

查看：

```css
git remote -v
```

------

### 7️⃣ 推送到 GitHub

```css
git push origin main
```

首次推送（推荐）：

```css
git push -u origin main
```

以后直接：

```css
git push
```

------

### 8️⃣ 拉取远程最新代码

```css
git pull
```

------

## 三、分支相关（以后会用到）

### 9️⃣ 查看分支

```css
git branch
```

------

### 🔟 创建分支

```css
git branch 分支名
```

创建并切换：

```css
git checkout -b 分支名
```

------

### 11️⃣ 切换分支

```css
git checkout main
```

（新写法）

```css
git switch main
```

------

## 四、撤销 / 回退

### 12️⃣ 撤销未 add 的修改

```css
git checkout -- 文件名
```

------

### 13️⃣ 撤销已 add（但没 commit）

```css
git reset HEAD 文件名
```

------

### 14️⃣ 回退到上一次提交（不删代码）

```css
git reset --soft HEAD~1
```

------

### 15️⃣ 回退并丢弃修改（慎用）

```css
git reset --hard HEAD~1
```

------

## 五、强制推送

⚠️ **非常危险，只在你确定要覆盖远程时用**

```css
git push -f origin main
```

## 六、特殊情况

### 1️⃣ Git 仓库乱了，想重新来

```shell
rd /s /q .git
git init
git add .
git commit -m "重新初始化仓库"
```

------

### 2️⃣ 之前绑错了 GitHub 仓库

直接删 `.git`，重新绑定一个干净的

------

### 3️⃣ 想把别人项目“脱离原仓库”

保留代码，不保留提交历史

------

## ⚠️ 注意事项（很重要）

❗ **不可恢复**

- 删除 `.git` 后，所有提交记录都没了
- 想恢复只能重新 clone

❗ **一定要在正确目录执行**

```shell
dir
```

确认当前目录确实是你的项目根目录
 再执行 `rd /s /q .git`

------

## 删除后常见下一步（推荐流程）

### 重新推送到 GitHub

```shell
git init
git branch -M main
git remote add origin https://github.com/用户名/仓库名.git
git add .
git commit -m "initial commit"
git push -u origin main
```
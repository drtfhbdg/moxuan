+++
date = '2026-02-22T16:45:28+08:00'
draft = false
title = 'Telegram端口流量查询机器人'

tags = ["vps"]

+++

# 告别臃肿面板！手写一个极简 Telegram 端口流量查询机器人

对于喜欢折腾 VPS、做端口转发或与朋友合租节点的人来说，分配端口和限制流量是刚需。市面上主流的方案通常是安装庞大的网页面板（如 3x-ui 或各类转发面板），但如果你和我一样有“代码洁癖”，只想要一个**干干净净的纯命令行环境**，同时又想给小伙伴提供一个**高逼格的自助查询服务**，那么这篇教程就是为你量身定制的。

### 💡 我们的终极架构：前后端分离玩法

- **后端（底层限速）：** 使用开源的 `Port Traffic Dog`（端口流量狗），在系统底层通过 `iptables/nftables` 精准统计流量，并在超量时铁面无私地切断端口。
- **前端（客户交互）：** 自己跑一个轻量级的 Python Telegram 机器人。它不干涉系统规则，只负责去读取“流量狗”的本地 JSON 数据，并在 TG 里给客户展示漂亮的“通行证”报表。

------

## 第一步：安装“端口流量狗” (底层核心)

首先，我们需要在服务器上安装大佬开源的轻量级流量控制脚本。

SSH 登录你的 VPS，执行以下一键安装命令：

Bash

```python
wget -O port-traffic-dog.sh https://raw.githubusercontent.com/zywe03/realm-xwPF/main/port-traffic-dog.sh && chmod +x port-traffic-dog.sh && ./port-traffic-dog.sh
```

*(注：如果国内机访问 GitHub 慢，可以在网址前加上加速前缀)*

安装完成后，以后只需在终端输入 `dog` 回车，即可呼出中文可视化菜单。你可以直接在里面**添加端口、设置流量限额（支持GB/TB/无限）、设置每月重置日期**。 设置好之后，底层的工作就完全交给流量狗去默默守护了。

------

## 第二步：申请 Telegram 机器人 (你的传话筒)

我们需要去 Telegram 官方申请一个专属的机器人账号：

1. 在 TG 搜索 `@BotFather`。
2. 发送 `/newbot`，按照提示给机器人起个名字和用户名（必须以 `_bot` 结尾）。
3. 成功后，你会得到一串 **Bot Token**（类似 `123456:ABCDefg...`），妥善保存。
4. 顺便搜索 `@userinfobot`，发送任意消息，获取你自己的 **纯数字 ID**（一串数字，这就是你的管理员凭证）。

------

## 第三步：部署我们的 Python 查询机器人

这是本文的核心！我们需要让机器人读取流量狗的数据并优雅地展示给用户。

### 1. 安装依赖库

Bash

```python
apt update && apt install python3 python3-pip -y
```

安装 TG 机器人通信库（如果你的系统是较新的 Debian 12 或 Ubuntu 24，可能会报错，请务必加上 `--break-system-packages`）：

Bash

```python
pip3 install pyTelegramBotAPI --break-system-packages
```

### 2. 创建机器人代码文件

Bash

```
nano dog_tg_bot.py
```

将下面的代码完整粘贴进去，并**替换成你自己的 `BOT_TOKEN` 和 `ADMIN_ID`**：

Python

```python
import os
import json
import telebot

# ================= 核心配置区 =================
BOT_TOKEN = "你的_BOT_TOKEN_填在这里"
ADMIN_ID = 123456789  # 填入你的管理员 TG ID (纯数字)

# 路径配置
TG_BIND_DB = "tg_bind.json"
DOG_CONFIG_FILE = "/etc/port-traffic-dog/config.json"
DOG_DATA_FILE = "/etc/port-traffic-dog/traffic_data.json"
# ==========================================

bot = telebot.TeleBot(BOT_TOKEN)

def load_bind_db():
    if not os.path.exists(TG_BIND_DB):
        return {}
    with open(TG_BIND_DB, 'r') as f:
        return json.load(f)

def save_bind_db(data):
    with open(TG_BIND_DB, 'w') as f:
        json.dump(data, f, indent=4)

def get_dog_data(port):
    """跨文件读取流量狗的底层配置与实时流量"""
    port_str = str(port)
    limit_gb = 0.0
    used_gb = 0.0
    is_unlimited = False
    reset_day = 1
    
    # 解析限额配置
    try:
        if os.path.exists(DOG_CONFIG_FILE):
            with open(DOG_CONFIG_FILE, 'r', encoding='utf-8') as f:
                cfg = json.load(f)
                quota = cfg.get("ports", {}).get(port_str, {}).get("quota", {})
                if quota.get("enabled"):
                    reset_day = quota.get("reset_day", 1)
                    limit_str = str(quota.get("monthly_limit", "0")).upper()
                    if limit_str == "UNLIMITED":
                        is_unlimited = True
                    elif "GB" in limit_str:
                        limit_gb = float(limit_str.replace("GB", ""))
                    elif "TB" in limit_str:
                        limit_gb = float(limit_str.replace("TB", "")) * 1024
                    elif "MB" in limit_str:
                        limit_gb = float(limit_str.replace("MB", "")) / 1024
                    else:
                        limit_gb = float(limit_str)
    except Exception as e:
        pass

    # 解析实时已用流量
    try:
        if os.path.exists(DOG_DATA_FILE):
            with open(DOG_DATA_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                port_data = data.get(port_str, {})
                if port_data:
                    in_bytes = int(port_data.get("input", 0))
                    out_bytes = int(port_data.get("output", 0))
                    used_gb = (in_bytes + out_bytes) / (1024 ** 3)
    except Exception as e:
        pass
        
    return limit_gb, round(used_gb, 4), is_unlimited, reset_day

# ================= 管理员命令：人员开通 =================
@bot.message_handler(commands=['bind'])
def admin_bind_user(message):
    if message.from_user.id != ADMIN_ID:
        return bot.reply_to(message, "⛔ 权限不足。")
    
    try:
        args = message.text.split()
        user_id = str(args[1])
        port = int(args[2])
        
        db = load_bind_db()
        db[user_id] = port
        save_bind_db(db)
        
        limit, used, is_unlim, reset_day = get_dog_data(port)
        limit_show = "无限容量" if is_unlim else f"{limit} GB"
        
        reply_msg = (f"✅ **用户开通成功！**\n"
                     f"👤 客户 ID: `{user_id}`\n"
                     f"🔗 绑定通道: `{port}`\n"
                     f"📦 初始限额: `{limit_show}`\n"
                     f"🔄 重置规则: 每月 `{reset_day}` 日")
        bot.reply_to(message, reply_msg, parse_mode="Markdown")
    except Exception as e:
        bot.reply_to(message, "❌ 格式错误！请使用: `/bind 用户ID 通道号`", parse_mode="Markdown")

# ================= 普通用户：自助查询 =================
@bot.message_handler(commands=['start', 'traffic', 'cx'])
def user_query_traffic(message):
    user_id = str(message.from_user.id)
    db = load_bind_db()
    
    if user_id in db:
        port = db[user_id]
        limit_gb, used_gb, is_unlim, reset_day = get_dog_data(port)
        
        if is_unlim:
            limit_show = "无限容量"
            remain_show = "无限"
            status_icon = "🟢 运行良好"
            percent_show = ""
        else:
            limit_show = f"{limit_gb} GB"
            remain = round(limit_gb - used_gb, 2)
            remain_show = f"{remain if remain > 0 else 0} GB"
            status_icon = "🟢 运行良好" if used_gb < limit_gb else "🔴 流量已耗尽"
            percent = round((used_gb / limit_gb) * 100, 1) if limit_gb > 0 else 0
            percent_show = f" ({percent}%)"

        report = (
            f"✨ **专属网络通行证** ✨\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"📦 **总计额度：** `{limit_show}`\n"
            f"📤 **当前已用：** `{used_gb} GB` `{percent_show}`\n"
            f"📉 **剩余可用：** `{remain_show}`\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"💡 **服务状态：** {status_icon}\n"
            f"🔄 **数据结算：** `每月 {reset_day} 日自动刷新流量`"
        )
        bot.reply_to(message, report, parse_mode="Markdown")
    else:
        bot.reply_to(message, f"⛔ 您的账号尚未激活。\n请将您的 ID `{user_id}` 发送给管理员获取通行证。")

print("🚀 尊享版机器人已启动！")
bot.infinity_polling()
```

### 3. 后台永久运行

保存退出后，让它在后台默默打工：

Bash

```python
nohup python3 dog_tg_bot.py > bot.log 2>&1 &
```

------

## 第四步：如何使用？（极其优雅）

整个使用流程完全告别了复杂的配置：

1. **添加底层规则：** 你在 SSH 终端用 `dog` 命令给朋友开一个端口，比如 `10003`，限额 `500GB`。
2. **在 TG 绑定账号：** 朋友进入机器人获取他的数字 ID 发给你。你用自己的号向机器人发送 `/bind 朋友的ID 10003`。
3. **朋友自助查询：** 朋友给机器人发送 `/cx` 或 `/traffic`，立刻就能收到一张漂亮、脱敏、隐藏了端口号和技术细节的“专属网络通行证”报表！

大功告成！这套系统既保留了 Linux 纯命令行的干净清爽，又提供了媲美商业面板的客户体验，简直是强迫症患者的福音。
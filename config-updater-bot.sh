#!/bin/bash

BOT_DIR="$HOME/update_bot"
SERVICE_FILE="/etc/systemd/system/updatebot.service"
BOT_PY="$BOT_DIR/bot.py"
CONFIG_FILE="$BOT_DIR/config.json"

install_bot() {
  echo "=== شروع نصب و راه‌اندازی ربات بروزرسانی کانفیگ ==="
  read -p "توکن ربات تلگرام را وارد کن: " BOT_TOKEN
  read -p "آیدی عددی تلگرام ادمین را وارد کن: " ADMIN_ID

  mkdir -p "$BOT_DIR"

  echo "در حال ایجاد فایل bot.py ..."
  cat > "$BOT_PY" <<EOF
import json
from telegram import Update
from telegram.ext import ApplicationBuilder, MessageHandler, CommandHandler, filters, ContextTypes
import re
import urllib.parse
import os

CONFIG_FILE = "config.json"

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            return {
                "domain": "mydomain.ir",
                "host": "myhost.ir",
                "subdomain": "mysubdomain.ir",
                "bot_token": "",
                "admin_id": 0
            }
    else:
        return {
            "domain": "mydomain.ir",
            "host": "myhost.ir",
            "subdomain": "mysubdomain.ir",
            "bot_token": "",
            "admin_id": 0
        }

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f)

state = load_config()

BOT_TOKEN = state.get("bot_token", "")
ADMIN_ID = state.get("admin_id", 0)

def is_admin(update: Update):
    return update.effective_user.id == ADMIN_ID

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_name = update.effective_user.first_name or "کاربر عزیز"
    await update.message.reply_text(
        f"سلام {user_name} عزیز! 🤖\n"
        "ربات بروزرسانی کانفیگ در خدمت شماست.\n"
        "لطفاً کانفیگ یا لینک خود را جهت بروزرسانی ارسال کنید."
    )

async def set_domain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً دامنه جدید را وارد کنید.\nمثال: /setdomain example.com")
    state["domain"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ دامنه جدید تنظیم شد: {state['domain']}")

async def set_host(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً مقدار host جدید را وارد کنید.\nمثال: /sethost myhost.com")
    state["host"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ هاست جدید تنظیم شد: {state['host']}")

async def set_subdomain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً دامنه سابسکریپشن جدید را وارد کنید.\nمثال: /setsub subscription.com")
    state["subdomain"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ دامنه سابسکریپشن جدید تنظیم شد: {state['subdomain']}")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text.strip()
    if text.startswith("vless://"):
        match = re.match(r"(vless://[^@]+@)([^:]+)(:\d+\?[^#]+)(#?.*)", text)
        if match:
            prefix, old_domain, middle, suffix = match.groups()
            updated_link = f"{prefix}{state['domain']}{middle}{suffix}"

            parsed = urllib.parse.urlparse(updated_link.replace("vless://", "http://"))
            query = urllib.parse.parse_qs(parsed.query)

            if 'host' in query:
                query['host'] = [state['host']]

            new_query = urllib.parse.urlencode(query, doseq=True)
            port = f":{parsed.port}" if parsed.port else ""
            rebuilt = f"vless://{parsed.username}@{state['domain']}{port}?{new_query}{suffix}"

            await update.message.reply_text(f"\n{rebuilt}")
        else:
            await update.message.reply_text("❌ فرمت لینک قابل شناسایی نیست.")
    elif text.startswith("http://") or text.startswith("https://"):
        try:
            parsed_url = urllib.parse.urlparse(text)
            new_netloc = state.get("subdomain", parsed_url.netloc)
            rebuilt_url = parsed_url._replace(netloc=new_netloc).geturl()
            await update.message.reply_text(f"\n{rebuilt_url}")
        except Exception:
            await update.message.reply_text("❌ فرمت لینک سابسکریپشن قابل شناسایی نیست.")
    else:
        await update.message.reply_text("❌ لطفاً یک کانفیگ یا لینک معتبر ارسال کنید.")

app = ApplicationBuilder().token(BOT_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CommandHandler("setdomain", set_domain))
app.add_handler(CommandHandler("sethost", set_host))
app.add_handler(CommandHandler("setsub", set_subdomain))
app.add_handler(MessageHandler(filters.TEXT, handle_message))
app.run_polling()
EOF

  echo "در حال ذخیره تنظیمات اولیه..."
  echo "{"domain": "mydomain.ir", "host": "myhost.ir", "subdomain": "mysubdomain.ir", "bot_token": "$BOT_TOKEN", "admin_id": $ADMIN_ID}" > "$CONFIG_FILE"

  echo "در حال نصب پیش‌نیازهای Python ..."
  pip3 install python-telegram-bot --quiet

  echo "در حال ایجاد فایل سرویس systemd ..."
  sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Config Updater Bot
After=network.target

[Service]
User=$USER
WorkingDirectory=$BOT_DIR
ExecStart=/usr/bin/python3 $BOT_PY
Restart=always

[Install]
WantedBy=multi-user.target
EOL

  echo "فعال‌سازی سرویس systemd ..."
  sudo systemctl daemon-reload
  sudo systemctl enable updatebot.service
  sudo systemctl start updatebot.service

  echo "ربات با موفقیت نصب و اجرا شد."
  echo "برای مشاهده وضعیت سرویس دستور زیر را اجرا کنید:"
  echo "sudo systemctl status updatebot.service"
}

remove_bot() {
  echo "در حال حذف کامل ربات..."
  sudo systemctl stop updatebot.service
  sudo systemctl disable updatebot.service
  sudo rm -f $SERVICE_FILE
  sudo systemctl daemon-reload
  rm -rf "$BOT_DIR"
  echo "ربات با موفقیت حذف شد."
}

update_bot() {
  echo "در حال بروزرسانی ربات..."
  sudo systemctl stop updatebot.service

  if [ -f "$CONFIG_FILE" ]; then
    BOT_TOKEN=$(jq -r '.bot_token' "$CONFIG_FILE")
    ADMIN_ID=$(jq -r '.admin_id' "$CONFIG_FILE")
    DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")
    HOST=$(jq -r '.host' "$CONFIG_FILE")
    SUBDOMAIN=$(jq -r '.subdomain' "$CONFIG_FILE")
  else
    echo "خطا: فایل پیکربندی پیدا نشد!"
    sudo systemctl start updatebot.service
    return
  fi

  echo "حذف کامل فایل‌های قبلی..."
  rm -rf "$BOT_DIR"

  echo "نصب مجدد ربات با حفظ تنظیمات..."
  mkdir -p "$BOT_DIR"

  cat > "$BOT_PY" <<EOF
import json
from telegram import Update
from telegram.ext import ApplicationBuilder, MessageHandler, CommandHandler, filters, ContextTypes
import re
import urllib.parse
import os

CONFIG_FILE = "config.json"

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            return {
                "domain": "mydomain.ir",
                "host": "myhost.ir",
                "subdomain": "mysubdomain.ir",
                "bot_token": "",
                "admin_id": 0
            }
    else:
        return {
            "domain": "mydomain.ir",
            "host": "myhost.ir",
            "subdomain": "mysubdomain.ir",
            "bot_token": "",
            "admin_id": 0
        }

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f)

state = load_config()

BOT_TOKEN = state.get("bot_token", "")
ADMIN_ID = state.get("admin_id", 0)

def is_admin(update: Update):
    return update.effective_user.id == ADMIN_ID

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_name = update.effective_user.first_name or "کاربر عزیز"
    await update.message.reply_text(
        f"سلام {user_name} عزیز! 🤖\n"
        "ربات بروزرسانی کانفیگ در خدمت شماست.\n"
        "لطفاً کانفیگ یا لینک خود را جهت بروزرسانی ارسال کنید."
    )

async def set_domain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً دامنه جدید را وارد کنید.\nمثال: /setdomain example.com")
    state["domain"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ دامنه جدید تنظیم شد: {state['domain']}")

async def set_host(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً مقدار host جدید را وارد کنید.\nمثال: /sethost myhost.com")
    state["host"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ هاست جدید تنظیم شد: {state['host']}")

async def set_subdomain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return await update.message.reply_text("❌ دسترسی ندارید.")
    if not context.args:
        return await update.message.reply_text("❗ لطفاً دامنه سابسکریپشن جدید را وارد کنید.\nمثال: /setsub subscription.com")
    state["subdomain"] = context.args[0]
    save_config(state)
    await update.message.reply_text(f"✅ دامنه سابسکریپشن جدید تنظیم شد: {state['subdomain']}")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text.strip()
    if text.startswith("vless://"):
        match = re.match(r"(vless://[^@]+@)([^:]+)(:\d+\?[^#]+)(#?.*)", text)
        if match:
            prefix, old_domain, middle, suffix = match.groups()
            updated_link = f"{prefix}{state['domain']}{middle}{suffix}"

            parsed = urllib.parse.urlparse(updated_link.replace("vless://", "http://"))
            query = urllib.parse.parse_qs(parsed.query)

            if 'host' in query:
                query['host'] = [state['host']]

            new_query = urllib.parse.urlencode(query, doseq=True)
            port = f":{parsed.port}" if parsed.port else ""
            rebuilt = f"vless://{parsed.username}@{state['domain']}{port}?{new_query}{suffix}"

            await update.message.reply_text(f"\n{rebuilt}")
        else:
            await update.message.reply_text("❌ فرمت لینک قابل شناسایی نیست.")
    elif text.startswith("http://") or text.startswith("https://"):
        try:
            parsed_url = urllib.parse.urlparse(text)
            new_netloc = state.get("subdomain", parsed_url.netloc)
            rebuilt_url = parsed_url._replace(netloc=new_netloc).geturl()
            await update.message.reply_text(f"\n{rebuilt_url}")
        except Exception:
            await update.message.reply_text("❌ فرمت لینک سابسکریپشن قابل شناسایی نیست.")
    else:
        await update.message.reply_text("❌ لطفاً یک کانفیگ یا لینک معتبر ارسال کنید.")

app = ApplicationBuilder().token(BOT_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CommandHandler("setdomain", set_domain))
app.add_handler(CommandHandler("sethost", set_host))
app.add_handler(CommandHandler("setsub", set_subdomain))
app.add_handler(MessageHandler(filters.TEXT, handle_message))
app.run_polling()
EOF

  echo "{"domain": "$DOMAIN", "host": "$HOST", "subdomain": "$SUBDOMAIN", "bot_token": "$BOT_TOKEN", "admin_id": $ADMIN_ID}" > "$CONFIG_FILE"

  sudo systemctl daemon-reload
  sudo systemctl enable updatebot.service
  sudo systemctl start updatebot.service

  echo "ربات با موفقیت بروزرسانی شد."
}

show_menu() {
  echo "========== ربات بروزرسانی کانفیگ =========="
  echo "1) نصب ربات"
  echo "2) حذف ربات"
  echo "3) بروزرسانی ربات"
  echo "4) خروج"
  echo "=========================================="
  read -p "یک گزینه انتخاب کنید: " choice
  case $choice in
    1) install_bot ;;
    2) remove_bot ;;
    3) update_bot ;;
    4) exit 0 ;;
    *) echo "گزینه نامعتبر!" ;;
  esac
}

while true; do
  show_menu
done

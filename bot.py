import json
import os
import re
import urllib.parse
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

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
                "admin_id": 0,
                "users": []
            }
    else:
        return {
            "domain": "mydomain.ir",
            "host": "myhost.ir",
            "subdomain": "mysubdomain.ir",
            "bot_token": "",
            "admin_id": 0,
            "users": []
        }

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f)

state = load_config()

BOT_TOKEN = state.get("bot_token", "")
ADMIN_ID = state.get("admin_id", 0)
users = set(state.get("users", []))  # Use a set to avoid duplicates

def is_admin(update: Update):
    return update.effective_user.id == ADMIN_ID

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name or "کاربر عزیز"

    # ثبت کاربر جدید
    if user_id not in users:
        users.add(user_id)
        state["users"] = list(users)
        save_config(state)

    # منوی دکمه‌ها
    buttons = []
    if is_admin(update):
        buttons = [
            [InlineKeyboardButton("📢 ارسال پیام به همه", callback_data="broadcast")],
            [InlineKeyboardButton("⚙️ تنظیمات", callback_data="settings")]
        ]
    keyboard = InlineKeyboardMarkup(buttons) if buttons else None

    await update.message.reply_text(
        f"سلام {user_name} عزیز! 🤖\nربات بروزرسانی کانفیگ در خدمت شماست.\nلطفاً کانفیگ یا لینک خود را جهت بروزرسانی ارسال کنید.",
        reply_markup=keyboard
    )

# دکمه های تنظیمات
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if data == "broadcast":
        if not is_admin(update):
            await query.edit_message_text("❌ دسترسی ندارید.")
            return
        await query.edit_message_text("لطفاً پیام خود را ارسال کنید:")
        context.user_data["awaiting_broadcast"] = True

    elif data == "settings":
        if not is_admin(update):
            await query.edit_message_text("❌ دسترسی ندارید.")
            return
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton(f"تنظیم دامنه vless (فعلی: {state.get('domain')})", callback_data="set_domain")],
            [InlineKeyboardButton(f"تنظیم هاست vless (فعلی: {state.get('host')})", callback_data="set_host")],
            [InlineKeyboardButton(f"تنظیم ساب دامین سابسکریبشن (فعلی: {state.get('subdomain')})", callback_data="set_subdomain")],
            [InlineKeyboardButton("بازگشت ↩️", callback_data="back_main")]
        ])
        await query.edit_message_text("لطفاً یکی از گزینه‌های تنظیمات را انتخاب کنید:", reply_markup=keyboard)

    elif data == "back_main":
        if not is_admin(update):
            await query.edit_message_text("❌ دسترسی ندارید.")
            return
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("📢 ارسال پیام به همه", callback_data="broadcast")],
            [InlineKeyboardButton("⚙️ تنظیمات", callback_data="settings")]
        ])
        await query.edit_message_text("منو اصلی:", reply_markup=keyboard)

    elif data in ["set_domain", "set_host", "set_subdomain"]:
        if not is_admin(update):
            await query.edit_message_text("❌ دسترسی ندارید.")
            return
        prompts = {
            "set_domain": "لطفاً دامنه vless جدید را ارسال کنید:",
            "set_host": "لطفاً هاست vless جدید را ارسال کنید:",
            "set_subdomain": "لطفاً ساب دامین لینک سابسکریبشن جدید را ارسال کنید:"
        }
        await query.edit_message_text(prompts[data])
        context.user_data["awaiting_setting"] = data

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()

    # ثبت کاربر جدید (اگر هنوز ثبت نشده)
    if user_id not in users:
        users.add(user_id)
        state["users"] = list(users)
        save_config(state)

    # اگر در انتظار پیام برای ارسال به همه هستیم
    if context.user_data.get("awaiting_broadcast"):
        if not is_admin(update):
            await update.message.reply_text("❌ دسترسی ندارید.")
            context.user_data["awaiting_broadcast"] = False
            return
        msg = text
        sent_count = 0
        for uid in users:
            try:
                await context.bot.send_message(chat_id=uid, text=msg)
                sent_count += 1
            except Exception:
                pass
        await update.message.reply_text(f"پیام شما به {sent_count} کاربر ارسال شد.")
        context.user_data["awaiting_broadcast"] = False
        return

    # اگر در انتظار تنظیم مقدار خاص هستیم
    if "awaiting_setting" in context.user_data:
        if not is_admin(update):
            await update.message.reply_text("❌ دسترسی ندارید.")
            context.user_data.pop("awaiting_setting")
            return
        setting = context.user_data["awaiting_setting"]
        state_map = {
            "set_domain": "domain",
            "set_host": "host",
            "set_subdomain": "subdomain"
        }
        state_key = state_map.get(setting)
        if not text:
            await update.message.reply_text("ورودی نامعتبر است.")
            return
        state[state_key] = text
        save_config(state)
        await update.message.reply_text(f"✅ مقدار {state_key} با موفقیت تنظیم شد.")
        context.user_data.pop("awaiting_setting")
        return

    # پردازش پیام‌های کانفیگ و لینک (همانند قبلی)
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

# دستورهای مدیریت
async def set_host(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        await update.message.reply_text("❌ دسترسی ندارید.")
        return
    await update.message.reply_text("لطفاً هاست vless جدید را ارسال کنید:")
    context.user_data["awaiting_setting"] = "set_host"

async def set_domain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        await update.message.reply_text("❌ دسترسی ندارید.")
        return
    await update.message.reply_text("لطفاً دامنه vless جدید را ارسال کنید:")
    context.user_data["awaiting_setting"] = "set_domain"

async def set_subdomain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        await update.message.reply_text("❌ دسترسی ندارید.")
        return
    await update.message.reply_text("لطفاً ساب دامین لینک سابسکریبشن جدید را ارسال کنید:")
    context.user_data["awaiting_setting"] = "set_subdomain"

app = ApplicationBuilder().token(BOT_TOKEN).build()

app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button_handler))
app.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), handle_message))

# دستورات ادمین
app.add_handler(CommandHandler("sethost", set_host))
app.add_handler(CommandHandler("setdomain", set_domain))
app.add_handler(CommandHandler("setsub", set_subdomain))

app.run_polling()

import json
import os
import re
import urllib.parse
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from telegram.constants import ParseMode

CONFIG_FILE = "config.json"

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            return default_config()
    else:
        return default_config()

def default_config():
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
users = set(state.get("users", []))

def is_admin(update: Update):
    return update.effective_user.id == ADMIN_ID

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name or "کاربر عزیز"

    if user_id not in users:
        users.add(user_id)
        state["users"] = list(users)
        save_config(state)

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

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if not is_admin(update):
        await query.edit_message_text("❌ دسترسی ندارید.")
        return

    if data == "broadcast":
        await query.edit_message_text("لطفاً پیام خود را ارسال کنید:")
        context.user_data["awaiting_broadcast"] = True
        context.user_data.pop("broadcast_confirm", None)
        context.user_data.pop("broadcast_msg", None)

    elif data == "confirm_broadcast":
        msg = context.user_data.get("broadcast_msg")
        if not msg:
            await query.edit_message_text("❌ پیامی برای ارسال وجود ندارد.")
            context.user_data.clear()
            return

        sent_count = 0
        for uid in users:
            try:
                await context.bot.send_message(chat_id=uid, text=msg)
                sent_count += 1
            except Exception:
                pass
        await query.edit_message_text(f"✅ پیام شما به {sent_count} کاربر ارسال شد.")
        context.user_data.clear()

    elif data == "cancel_broadcast":
        await query.edit_message_text("❌ ارسال پیام به همه لغو شد.")
        context.user_data.clear()

    elif data == "settings":
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton(f"تنظیم دامنه vless (فعلی: {state.get('domain')})", callback_data="set_domain")],
            [InlineKeyboardButton(f"تنظیم هاست vless (فعلی: {state.get('host')})", callback_data="set_host")],
            [InlineKeyboardButton(f"تنظیم ساب دامین سابسکریبشن (فعلی: {state.get('subdomain')})", callback_data="set_subdomain")],
            [InlineKeyboardButton("بازگشت ↩️", callback_data="back_main")]
        ])
        await query.edit_message_text("لطفاً یکی از گزینه‌های تنظیمات را انتخاب کنید:", reply_markup=keyboard)

    elif data == "back_main":
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("📢 ارسال پیام به همه", callback_data="broadcast")],
            [InlineKeyboardButton("⚙️ تنظیمات", callback_data="settings")]
        ])
        await query.edit_message_text("منو اصلی:", reply_markup=keyboard)

    elif data in ["set_domain", "set_host", "set_subdomain"]:
        prompts = {
            "set_domain": "لطفاً دامنه vless جدید را ارسال کنید:",
            "set_host": "لطفاً هاست vless جدید را ارسال کنید:",
            "set_subdomain": "لطفاً ساب دامین لینک سابسکریبشن جدید را ارسال کنید:"
        }
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("❌ انصراف", callback_data="cancel_setting")]
        ])
        await query.edit_message_text(prompts[data], reply_markup=keyboard)
        context.user_data["awaiting_setting"] = data

    elif data == "cancel_setting":
        await query.edit_message_text("❌ عملیات تنظیمات لغو شد.")
        context.user_data.pop("awaiting_setting", None)

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()

    if user_id not in users:
        users.add(user_id)
        state["users"] = list(users)
        save_config(state)

    if text == "/cancel":
        context.user_data.clear()
        await update.message.reply_text("✅ عملیات با موفقیت لغو شد.")
        return

    if context.user_data.get("awaiting_broadcast") and not context.user_data.get("broadcast_confirm"):
        if not is_admin(update):
            await update.message.reply_text("❌ دسترسی ندارید.")
            context.user_data["awaiting_broadcast"] = False
            return

        context.user_data["broadcast_msg"] = text
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("✅ تأیید ارسال", callback_data="confirm_broadcast")],
            [InlineKeyboardButton("❌ انصراف", callback_data="cancel_broadcast")]
        ])
        await update.message.reply_text(
            f"پیش‌نمایش پیام:\n\n{text}\n\nلطفاً تأیید یا انصراف دهید.",
            reply_markup=keyboard
        )
        context.user_data["broadcast_confirm"] = True
        return

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
        key = state_map.get(setting)
        state[key] = text
        save_config(state)
        await update.message.reply_text(f"✅ مقدار {key} با موفقیت ذخیره شد.")
        context.user_data.pop("awaiting_setting")
        return

    if text.startswith("vless://"):
        match = re.match(r"(vless://[^@]+@)([^:]+)(:\d+\?[^#]+)(#?.*)", text)
        if match:
            prefix, _, middle, suffix = match.groups()
            updated_link = f"{prefix}{state['domain']}{middle}{suffix}"
            parsed = urllib.parse.urlparse(updated_link.replace("vless://", "http://"))
            query = urllib.parse.parse_qs(parsed.query)
            if 'host' in query:
                query['host'] = [state['host']]
            new_query = urllib.parse.urlencode(query, doseq=True)
            port = f":{parsed.port}" if parsed.port else ""
            rebuilt = f"vless://{parsed.username}@{state['domain']}{port}?{new_query}{suffix}"
            await update.message.reply_text(rebuilt)
        else:
            await update.message.reply_text("❌ فرمت لینک قابل شناسایی نیست.")
    elif text.startswith("http://") or text.startswith("https://"):
        try:
            parsed_url = urllib.parse.urlparse(text)
            rebuilt_url = parsed_url._replace(netloc=state.get("subdomain", parsed_url.netloc)).geturl()
            await update.message.reply_text(rebuilt_url)
        except Exception:
            await update.message.reply_text("❌ فرمت لینک سابسکریپشن قابل شناسایی نیست.")
    else:
        await update.message.reply_text("❌ لطفاً یک کانفیگ یا لینک معتبر ارسال کنید.")

async def set_value_command(update: Update, context: ContextTypes.DEFAULT_TYPE, key: str, value: str):
    if not is_admin(update):
        await update.message.reply_text("❌ دسترسی ندارید.")
        return
    if not value:
        await update.message.reply_text("❌ مقدار مورد نظر را وارد کنید.")
        return
    state[key] = value
    save_config(state)
    await update.message.reply_text(f"✅ مقدار {key} با موفقیت ذخیره شد.")

async def set_host(update: Update, context: ContextTypes.DEFAULT_TYPE):
    value = " ".join(context.args)
    await set_value_command(update, context, "host", value)

async def set_domain(update: Update, context: ContextTypes.DEFAULT_TYPE):
    value = " ".join(context.args)
    await set_value_command(update, context, "domain", value)

async def set_sub(update: Update, context: ContextTypes.DEFAULT_TYPE):
    value = " ".join(context.args)
    await set_value_command(update, context, "subdomain", value)

app = ApplicationBuilder().token(BOT_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button_handler))
app.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), handle_message))
app.add_handler(CommandHandler("sethost", set_host))
app.add_handler(CommandHandler("setdomain", set_domain))
app.add_handler(CommandHandler("setsub", set_sub))

if __name__ == "__main__":
    print("Bot is running...")
    app.run_polling()

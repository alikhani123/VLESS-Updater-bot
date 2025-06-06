#!/bin/bash

BOT_DIR="$HOME/update_bot"
BOT_PY="$BOT_DIR/bot.py"
CONFIG_FILE="$BOT_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/updatebot.service"
BOT_RAW_URL="https://raw.githubusercontent.com/alikhani123/VLESS-Updater-bot/refs/heads/main/bot.py"

install_bot() {
  echo "=== Starting Config Updater Bot Installation ==="

  read -p "Enter your Telegram bot token: " BOT_TOKEN
  read -p "Enter the numeric Telegram admin ID: " ADMIN_ID

  mkdir -p "$BOT_DIR"

  echo "Downloading bot.py from GitHub..."
  curl -sSfL "$BOT_RAW_URL" -o "$BOT_PY" || {
    echo "❌ Failed to download bot.py. Please check the URL or your internet connection."
    return
  }

  echo "Saving initial configuration..."
  echo "{\"domain\": \"mydomain.ir\", \"host\": \"myhost.ir\", \"subdomain\": \"mysubdomain.ir\", \"bot_token\": \"$BOT_TOKEN\", \"admin_id\": $ADMIN_ID, \"users\": []}" > "$CONFIG_FILE"

  echo "Installing Python dependencies..."
  pip3 install --quiet python-telegram-bot

  echo "Creating systemd service file..."
  sudo bash -c "cat > $SERVICE_FILE" <<EOF
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
EOF

  echo "Enabling and starting the bot service..."
  sudo systemctl daemon-reload
  sudo systemctl enable updatebot.service
  sudo systemctl start updatebot.service

  echo "✅ Bot installed and running successfully!"
  echo "To check status: sudo systemctl status updatebot.service"
  echo "🌐 Project repo: https://github.com/alikhani123/VLESS-Updater-bot"
}

remove_bot() {
  echo "=== Removing bot completely ==="
  sudo systemctl stop updatebot.service
  sudo systemctl disable updatebot.service
  sudo rm -f "$SERVICE_FILE"
  sudo systemctl daemon-reload
  rm -rf "$BOT_DIR"
  echo "✅ Bot and all related files have been removed."
  echo "🌐 Project repo: https://github.com/alikhani123/VLESS-Updater-bot"
}

update_bot() {
  echo "=== Updating bot.py ==="

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ config.json not found! Update aborted."
    return
  fi

  echo "Stopping the service..."
  sudo systemctl stop updatebot.service

  echo "Downloading latest bot.py from GitHub..."
  curl -sSfL "$BOT_RAW_URL" -o "$BOT_PY" || {
    echo "❌ Failed to download bot.py. Please check the URL or your internet connection."
    sudo systemctl start updatebot.service
    return
  }

  echo "Installing/updating dependencies..."
  pip3 install --quiet python-telegram-bot

  echo "Restarting the bot service..."
  sudo systemctl daemon-reload
  sudo systemctl restart updatebot.service

  echo "✅ Bot updated successfully. Configuration was preserved."
  echo "🌐 Project repo: https://github.com/alikhani123/VLESS-Updater-bot"
}

show_menu() {
  echo "=== Config Updater Bot Installer Menu ==="
  echo "1) Install Bot"
  echo "2) Remove Bot"
  echo "3) Update Bot"
  echo "4) Exit"
  echo -n "Choose an option: "
  read opt
  case $opt in
    1) install_bot ;;
    2) remove_bot ;;
    3) update_bot ;;
    4) exit 0 ;;
    *) echo "Invalid option" ;;
  esac
}

while true; do
  show_menu
done

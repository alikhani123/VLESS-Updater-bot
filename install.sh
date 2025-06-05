#!/bin/bash

BOT_DIR="$HOME/update_bot"
SERVICE_FILE="/etc/systemd/system/updatebot.service"
BOT_PY="$BOT_DIR/bot.py"
CONFIG_FILE="$BOT_DIR/config.json"

install_bot() {
  echo "=== Starting Config Updater Bot Installation ==="
  read -p "Enter your Telegram bot token: " BOT_TOKEN
  read -p "Enter the numeric Telegram admin ID: " ADMIN_ID

  mkdir -p "$BOT_DIR"

  if [ ! -f "$BOT_PY" ]; then
    echo "Error: bot.py file not found in the current directory."
    echo "Please place bot.py in the current directory before installing."
    exit 1
  fi

  echo "Copying bot.py to $BOT_DIR ..."
  cp bot.py "$BOT_PY"
  chmod +x "$BOT_PY"

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating initial config.json ..."
    echo "{\"domain\": \"mydomain.ir\", \"host\": \"myhost.ir\", \"subdomain\": \"mysubdomain.ir\", \"bot_token\": \"$BOT_TOKEN\", \"admin_id\": $ADMIN_ID}" > "$CONFIG_FILE"
  fi

  echo "Installing Python prerequisites..."
  pip3 install python-telegram-bot --quiet

  echo "Creating systemd service file..."
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

  echo "Enabling and starting systemd service..."
  sudo systemctl daemon-reload
  sudo systemctl enable updatebot.service
  sudo systemctl start updatebot.service

  echo "Bot installed and running successfully."
  echo "To check the service status, run:"
  echo "sudo systemctl status updatebot.service"
}

remove_bot() {
  echo "Removing bot completely..."
  sudo systemctl stop updatebot.service
  sudo systemctl disable updatebot.service
  sudo rm -f $SERVICE_FILE
  sudo systemctl daemon-reload
  rm -rf "$BOT_DIR"
  echo "Bot removed successfully."
}

update_bot() {
  echo "Updating bot..."

  if [ ! -f "$BOT_PY" ]; then
    echo "Error: bot.py file not found in the current directory."
    echo "Please place bot.py in the current directory before updating."
    exit 1
  fi

  sudo systemctl stop updatebot.service

  echo "Copying new bot.py to $BOT_DIR ..."
  cp bot.py "$BOT_PY"
  chmod +x "$BOT_PY"

  echo "Installing python-telegram-bot..."
  pip3 install python-telegram-bot --quiet

  echo "Reloading and starting service..."
  sudo systemctl daemon-reload
  sudo systemctl enable updatebot.service
  sudo systemctl start updatebot.service

  echo "Bot updated successfully."
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

#!/bin/bash

echo "Welcome to the XMPlus Telegram NBot Installer!"
sudo apt update
sudo apt install python3-venv

# Step : Create a directory for the bot
sudo mkdir -p /etc/srvbt

# Step 1: Prompt user for Telegram token and Chat ID
read -p "Enter your Telegram Bot Token: " BOT_TOKEN
read -p "Enter your Chat ID: " CHAT_ID

# Save the provided BOT_TOKEN and CHAT_ID
echo "$BOT_TOKEN" > /etc/srvbt/bot_token.txt
echo "$CHAT_ID" > /etc/srvbt/chat_id.txt

# Step 3: Copy bot.py to the bot directory and replace placeholders
cat <<EOF > /etc/srvbt/bot.py
import os
import telebot
import subprocess
from telebot.types import ReplyKeyboardMarkup, KeyboardButton

BOT_TOKEN = '$BOT_TOKEN'
AUTHORIZED_USERS = [$CHAT_ID]

bot = telebot.TeleBot(BOT_TOKEN)

def is_authorized(chat_id):
    return chat_id in AUTHORIZED_USERS

# Create custom keyboard with buttons
command_buttons = ReplyKeyboardMarkup(row_width=3)
command_buttons.add(
    KeyboardButton('XMPlus reboot'),
    KeyboardButton('Systemreboot'),
    KeyboardButton('Ifconfig'),
    KeyboardButton('Execute on servers: server1,server2')
)

# Load registered servers from file
def load_registered_servers():
    try:
        with open('/etc/srvbt/registered_servers.txt', 'r') as f:
            return f.read().splitlines()
    except FileNotFoundError:
        return []

# Log command execution and the server that executed it
def log_command(chat_id, command):
    with open('/etc/srvbt/command_logs.txt', 'a') as f:
        f.write(f"Chat ID: {chat_id}, Command: {command}\n")

@bot.message_handler(commands=['start'])
def send_welcome(message):
    if is_authorized(message.chat.id):
        bot.send_message(message.chat.id, "Welcome! Please select a command:", reply_markup=command_buttons)
    else:
        bot.send_message(message.chat.id, "You are not authorized to use this bot.")

@bot.message_handler(func=lambda message: True)
def handle_command(message):
    if is_authorized(message.chat.id):
        if message.text == 'XMPlus reboot':
            command = 'XMPlus restart'
            output = subprocess.getoutput(command)
            bot.send_message(message.chat.id, output)
            log_command(message.chat.id, command)
        elif message.text == 'Systemreboot':
            command = 'reboot now'
            output = subprocess.getoutput(command)
            bot.send_message(message.chat.id, output)
            log_command(message.chat.id, command)
        elif message.text == 'Ifconfig':
            command = 'ifconfig'
            output = subprocess.getoutput(command)
            bot.send_message(message.chat.id, output)
            log_command(message.chat.id, command)
        elif message.text.startswith('Execute on servers:'):
            servers_to_execute = message.text[len('Execute on servers: '):].split(',')
            registered_servers = load_registered_servers()
            executed_servers = []
            for server in servers_to_execute:
                if server in registered_servers:
                    command_to_execute = ' '.join(message.text.split()[1:])
                    command = f'ssh {server} {command_to_execute}'
                    output = subprocess.getoutput(command)
                    bot.send_message(message.chat.id, f"Command executed on {server}:\n{output}")
                    executed_servers.append(server)
                    log_command(message.chat.id, f"Executed '{command_to_execute}' on {server}")
                else:
                    bot.send_message(message.chat.id, f"Server {server} is not registered.")
            if executed_servers:
                bot.send_message(message.chat.id, f"Executed on servers: {', '.join(executed_servers)}")
            else:
                bot.send_message(message.chat.id, "No valid servers to execute on.")
        else:
            bot.send_message(message.chat.id, "Invalid command selection.")
    else:
        bot.send_message(message.chat.id, "You are not authorized to use this bot.")

if __name__ == '__main__':
    bot.polling()
EOF

# Step 4: Create a virtual environment for the bot (optional)
python3 -m venv /etc/srvbt/bot-venv
source /etc/srvbt/bot-venv/bin/activate

# Step 5: Install required Python packages
pip install pyTelegramBotAPI

# Step 6: Copy bot.sh to /usr/bin/ and make it executable
cat <<EOF > /usr/bin/bot
#!/bin/bash

display_menu() {
    echo "XMPlusNBot Telegram  Control Menu:"
    echo "1. Start Bot"
    echo "2. Stop Bot"
    echo "3. Restart Bot"
    echo "4. Exit"
    echo
}

start_bot() {
    sudo systemctl start bot
    echo "Bot started."
}

stop_bot() {
    sudo systemctl stop bot
    echo "Bot stopped."
}

restart_bot() {
    sudo systemctl restart bot
    echo "Bot restarted."
}

while true; do
    display_menu
    read -p "Enter your choice: " choice
    case \$choice in
        1) start_bot ;;
        2) stop_bot ;;
        3) restart_bot ;;
        4) exit ;;
        *) echo "Invalid choice. Please select a valid option." ;;
    esac
done
EOF

chmod +x /usr/bin/bot

# Step 7: Create and set up the systemd service
cat <<EOF > /etc/systemd/system/bot.service
[Unit]
Description=Your Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=/etc/srvbt/bot-venv/bin/python /etc/srvbt/bot.py
WorkingDirectory=/etc/srvbt
User=root
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Step 8: Enable and start the bot service
source /etc/srvbt/bot-venv/bin/activate
sudo systemctl daemon-reload
sudo systemctl enable bot
sudo systemctl start bot

echo "Installation completed!"

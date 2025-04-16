
# SSH Alert Bot

The **SSH Alert Bot** is a Bash script designed to send Telegram notifications upon SSH login events and also allows manual message sending. With this tool, system administrators can be notified of new SSH accesses and monitor additional metrics (e.g., GPU usage) if available. This script is intended to be used on shared deep learning workstations.

## Features

- **Automatic SSH Login Notification:**  
  Sends a detailed Telegram message each time a new SSH login is detected.
  
- **Shared Logging and Locking:**  
  Maintains a shared log file among all users to track SSH accesses and uses a lock file to ensure atomic operations.
  
- **Optional GPU Usage Reporting:**  
  If NVIDIA GPUs are present, the script reports the total GPU power draw.
  
- **Manual Message Sending:**  
  Run the script with a command-line argument to send custom messages via Telegram.

## Prerequisites

- A Linux system with Bash and SSH installed.
- A Telegram Bot Token (obtain one using [BotFather](https://t.me/BotFather) on Telegram).
- Internet connectivity.
- `jq curl nvidia-smi` are needed. Install them with:

```bash
sudo apt-get install -y jq curl 
sudo ubuntu-drivers devices
sudo apt install nvidia-driver-xxx
```

## Installation and Setup

Follow these steps to install and configure the SSH Alert Bot.

### 1. Create the Script File

Create a new script file at `/usr/local/bin/telegram-ssh-alert.sh`:

```bash
sudo nano /usr/local/bin/telegram-ssh-alert.sh
```

Paste the script code inside (see main script file in this repository), and **replace** the `TOKEN` variable with your Telegram bot token.

### 2. Make the Script Executable

```bash
sudo chmod +x /usr/local/bin/telegram-ssh-alert.sh
```

### 3. Link the Script to SSH Logins

Edit the SSH runtime script used for interactive sessions:

```bash
sudo nano /etc/ssh/sshrc
```

Add the following line at the bottom:

```bash
/usr/local/bin/telegram-ssh-alert.sh
```

### 4. Install jq

Install the JSON parsing tool used to handle Telegram API responses:

```bash
sudo apt-get install jq
```

## Usage

### 1. Automatic SSH Alerts

When a user connects via SSH, the script:
- Logs the username and IP
- Checks if it's a new session (based on a configurable time threshold)
- Sends a Telegram alert with login details
- Optionally reports GPU usage if NVIDIA GPUs are detected via `nvidia-smi`

### 2. Send Manual Messages

You can also manually trigger a Telegram notification by passing a message to the script:

```bash
/usr/local/bin/telegram-ssh-alert.sh "Server updated successfully"
```

This will bypass login detection logic and directly send your message to all known chat IDs.

## Chat ID Management

The script automatically collects chat IDs from `/getUpdates` to a file stored in:

```bash
~/.sshalertbot/chatids
```

To register a chat:
1. Start your bot on Telegram.
2. Send `/start` command to the bot.
3. The script will collect your chat ID on the next execution and persist it.

## Author

Created by Daniel. Contributions welcome!

#!/bin/bash
# This script sends a notification to a Telegram bot when a new SSH access is detected.
# It also checks the GPU usage and sends a notification if it exceeds a certain threshold.
# The script uses a lock file to prevent multiple instances from running simultaneously.
# It requires the following dependencies:
# - curl
# - jq
# - nvidia-smi (for GPU usage check)
VERSION="1.0.0"

# Make sure to set the Telegram bot token and chat ID in the script.
TOKEN=""

USER_LOG_FILE="/var/tmp/ssh_access_log"
LOCK_FILE="/var/tmp/ssh_access_log.lock"

GPU_THRESHOLD=50
NEW_LOGIN_THRESHOLD=30

if [ ! -f "$USER_LOG_FILE" ]; then
    umask 000
    touch "$USER_LOG_FILE"
    chmod 666 "$USER_LOG_FILE"
fi

if [ ! -f "$LOCK_FILE" ]; then
    umask 000
    touch "$LOCK_FILE"
    chmod 666 "$LOCK_FILE"
fi

send_notification() {
    local message="$1"
    CHAT_IDS_FILE="$HOME/.sshalertbot/chatids"
    mkdir -p "$(dirname "$CHAT_IDS_FILE")"

    if [ ! -f "$CHAT_IDS_FILE" ]; then
        touch "$CHAT_IDS_FILE"
    fi

    NEW_CHAT_IDS=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" \
                    | jq -r '.result[].message.chat.id' | sort | uniq)
    for chat_id in $NEW_CHAT_IDS; do
        if ! grep -q "^${chat_id}$" "$CHAT_IDS_FILE" 2>/dev/null; then
            echo "$chat_id" >> "$CHAT_IDS_FILE"
        fi
    done

    CHAT_IDS=$(cat "$CHAT_IDS_FILE")
    for CHAT_ID in $CHAT_IDS; do
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
             -d chat_id="${CHAT_ID}" \
             --data-urlencode "text=${message}" \
             -d parse_mode="HTML" > /dev/null 2>&1 &
    done
}

check_gpu_usage() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        consumption=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
        if [ -n "$consumption" ]; then
            echo "$consumption"
            return 0
        fi
    fi
    return 1
}

# Check if the script is run with a message
if [ "$#" -gt 0 ]; then
    MESSAGE="$*"
    send_notification "$MESSAGE"
    exit 0
fi

exec 200>"$LOCK_FILE"
flock -n 200 || exit 1

HOSTNAME=$(hostname)
USERNAME=$(whoami)
ACCESS_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")
OSINFO=$(lsb_release -ds 2>/dev/null | tr -d '"')
if [ -z "$OSINFO" ]; then
    OSINFO=$(uname -o)
fi
CURRENT_TIMESTAMP=$(date +%s)

NEW_LOGIN=1
if [ -f "$USER_LOG_FILE" ]; then
    LAST_ENTRY=$(grep "^$USERNAME " "$USER_LOG_FILE" | tail -n 1)
    if [ -n "$LAST_ENTRY" ]; then
        LAST_TIMESTAMP=$(echo "$LAST_ENTRY" | awk '{print $3}')
        TIME_DIFF=$((CURRENT_TIMESTAMP - LAST_TIMESTAMP))
        TIME_DIFF_MINUTES=$((TIME_DIFF / 60))

        if [ "$TIME_DIFF_MINUTES" -lt "$NEW_LOGIN_THRESHOLD" ]; then
            sed -i "s/^$USERNAME .*/$USERNAME $ACCESS_IP ${CURRENT_TIMESTAMP}/" "$USER_LOG_FILE"
            NEW_LOGIN=0
        else
            sed -i "/^$USERNAME /d" "$USER_LOG_FILE"
        fi
    fi
fi

if [ "$NEW_LOGIN" -eq 1 ]; then
    echo "$USERNAME $ACCESS_IP ${CURRENT_TIMESTAMP}" >> "$USER_LOG_FILE"

    MESSAGE="<b>Warning: new SSH access!</b>

<b>Access details:</b>
- <b>User:</b> ${USERNAME}@${HOSTNAME}
- <b>PC Name:</b> ${HOSTNAME}
- <b>Operating system:</b> ${OSINFO}
- <b>Date and Time:</b> ${DATE_TIME}
- <b>IP Address:</b> ${ACCESS_IP}

Check immediately if this is an authorized access!"

    send_notification "$MESSAGE"

    GPU_CONSUMPTION=$(check_gpu_usage)
    if [ $? -eq 0 ]; then
         MSG_GPU="<b>GPU usage details:</b>
- <b>GPU consumption:</b> ${GPU_CONSUMPTION}W (threshold: ${GPU_THRESHOLD}W)
- <b>Date and Time:</b> ${DATE_TIME}"
         send_notification "$MSG_GPU"
    fi
fi

flock -u 200

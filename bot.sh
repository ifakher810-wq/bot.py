#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
#       VELOCLOUD DISCORD BOT INSTALLER
# ==========================================

ZIP_URL="https://github.com/ifakher810-wq/bot.py/raw/refs/heads/main/Discord_VPS_Bot_Files.zip"

ZIP_NAME="Discord_VPS_Bot_Files.zip"
BOT_DIR="$HOME/Discord_VPS_Bot"

R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
Y='\033[1;33m'
W='\033[1;37m'
N='\033[0m'

clear

echo -e "${C}"
cat <<'EOF'
 __     ______ _     ____  ____ _   _ ___
 \ \   / / ____| |   / ___||  _ \ | | |   \
  \ \ / /|  _| | |  | |    | |_) | | | | |) |
   \ V / | |___| |__| |___ |  __/| |_| |  _ <
    \_/  |_____|_____\____||_|    \___/|_| \_\

          DISCORD VPS BOT INSTALLER
EOF
echo -e "${N}"

trap 'echo -e "${R}Installation failed. Check the error above.${N}"' ERR

# Ubuntu detection
if [ ! -f /etc/os-release ]; then
    echo "Operating system not detected."
    exit 1
fi

source /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    echo "Ubuntu VPS required."
    exit 1
fi

echo -e "${G}[1/7] Ubuntu detected.${N}"

# Dependencies
echo -e "${Y}[2/7] Installing packages...${N}"

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

$SUDO apt-get update -y

$SUDO apt-get install -y \
    python3 python3-pip python3-venv \
    curl unzip ca-certificates

# Download ZIP
echo -e "${Y}[3/7] Downloading ZIP...${N}"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

curl -fL --retry 3 "$ZIP_URL" \
    -o "$TEMP_DIR/$ZIP_NAME"

unzip -t "$TEMP_DIR/$ZIP_NAME" >/dev/null

mkdir -p "$TEMP_DIR/extracted"

unzip -q "$TEMP_DIR/$ZIP_NAME" \
    -d "$TEMP_DIR/extracted"

BOT_FILE="$(find "$TEMP_DIR/extracted" \
    -type f -name bot.py -print -quit)"

if [ -z "$BOT_FILE" ]; then
    echo "ERROR: bot.py not found in ZIP."
    exit 1
fi

cp -a "$(dirname "$BOT_FILE")/." "$BOT_DIR/"

echo -e "${G}ZIP extracted successfully.${N}"

# Token and Owner ID
echo -e "${Y}[4/7] Discord configuration...${N}"

read -r -s -p "Enter Discord Bot Token: " BOT_TOKEN
echo

if [ -z "$BOT_TOKEN" ]; then
    echo "Token is empty."
    exit 1
fi

read -r -p "Enter Discord Owner ID: " OWNER_ID

if ! [[ "$OWNER_ID" =~ ^[0-9]{15,22}$ ]]; then
    echo "Invalid Owner ID."
    exit 1
fi

export BOT_TOKEN OWNER_ID BOT_DIR

python3 <<'PY'
import os
import re
import json
from pathlib import Path

p = Path(os.environ["BOT_DIR"]) / "bot.py"
s = p.read_text()

s, a = re.subn(
    r'(?m)^BOT_TOKEN\s*=.*$',
    'BOT_TOKEN = ' + json.dumps(os.environ["BOT_TOKEN"]),
    s,
    count=1
)

s, b = re.subn(
    r'(?m)^OWNER_ID\s*=.*$',
    'OWNER_ID = ' + os.environ["OWNER_ID"],
    s,
    count=1
)

if a != 1 or b != 1:
    raise SystemExit("BOT_TOKEN or OWNER_ID not found in bot.py")

p.write_text(s)
PY

chmod 600 "$BOT_DIR/bot.py"

# Python setup
echo -e "${Y}[5/7] Installing Python requirements...${N}"

cd "$BOT_DIR"

python3 -m venv .venv

.venv/bin/python -m pip install --upgrade pip

if [ -f requirements.txt ]; then
    .venv/bin/python -m pip install -r requirements.txt
else
    .venv/bin/python -m pip install discord.py
fi

# Syntax check
echo -e "${Y}[6/7] Checking bot.py...${N}"

.venv/bin/python -m py_compile bot.py

echo -e "${G}Syntax check passed.${N}"

# Start bot
echo -e "${Y}[7/7] Starting Discord Bot...${N}"

cd "$BOT_DIR"

nohup "$BOT_DIR/.venv/bin/python" \
    -u "$BOT_DIR/bot.py" \
    </dev/null > "$BOT_DIR/bot.log" 2>&1 &

PID=$!

echo "$PID" > "$BOT_DIR/bot.pid"

sleep 8

if ! kill -0 "$PID" 2>/dev/null; then
    echo -e "${R}Bot startup failed. Logs:${N}"
    tail -n 40 "$BOT_DIR/bot.log"
    exit 1
fi

echo
echo -e "${G}====================================${N}"
echo -e "${G}       BOT STARTED SUCCESSFULLY${N}"
echo -e "${G}====================================${N}"

echo "Bot PID: $PID"
echo "Bot Folder: $BOT_DIR"
echo "ZIP: $ZIP_NAME"

echo
echo "View Logs:"
echo "tail -f $BOT_DIR/bot.log"

echo
echo "Stop Bot:"
echo "kill $PID"

echo
echo -e "${G}VELOCLOUD INSTALLATION COMPLETE!${N}"

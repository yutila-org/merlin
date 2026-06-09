#!/usr/bin/env bash
set -e

if ! command -v git &> /dev/null; then
    echo -e "\033[1;31m[ERROR] 'git' is not installed.\033[0m"
    exit 1
fi

MERLIN_HOME="$HOME/.merlin"
if [ -d "$MERLIN_HOME" ]; then
    echo -e "\033[1;36m[UPDATE] Updating existing Merlin installation in $MERLIN_HOME...\033[0m"
    cd "$MERLIN_HOME"
    git pull origin main
else
    echo -e "\033[1;36m[INSTALL] Cloning Merlin to $MERLIN_HOME...\033[0m"
    git clone https://github.com/yutila-org/merlin.git "$MERLIN_HOME"
fi

mkdir -p "$MERLIN_HOME/bin"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then ARCH="arm64"; fi

echo -e "\033[1;36m[DOWNLOAD] Fetching system-specific binary for Merlin ($OS-$ARCH)...\033[0m"
URL="https://github.com/yutila-org/merlin/releases/download/alpha/merlin-${OS}-${ARCH}"
if [[ "$OS" == *"mingw"* || "$OS" == *"msys"* || "$OS" == *"cygwin"* ]]; then
    URL="https://github.com/yutila-org/merlin/releases/download/alpha/merlin-windows-amd64.exe"
    curl -sSL "$URL" -o "$MERLIN_HOME/bin/merlin.exe"
    chmod +x "$MERLIN_HOME/bin/merlin.exe"
else
    curl -sSL "$URL" -o "$MERLIN_HOME/bin/merlin"
    chmod +x "$MERLIN_HOME/bin/merlin"
fi

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then SHELL_PROFILE="$HOME/.zshrc"; elif [ -f "$HOME/.bashrc" ]; then SHELL_PROFILE="$HOME/.bashrc"; fi

if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "MERLIN_HOME" "$SHELL_PROFILE"; then
        echo -e "\n# Merlin Build Engine" >> "$SHELL_PROFILE"
        echo -e "export MERLIN_HOME=\"$MERLIN_HOME\"" >> "$SHELL_PROFILE"
        echo -e "export PATH=\"\$MERLIN_HOME/bin:\$PATH\"" >> "$SHELL_PROFILE"
    fi
fi
echo -e "\033[1;32m[SUCCESS] Merlin Engine installed to $MERLIN_HOME!\033[0m"

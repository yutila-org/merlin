#!/usr/bin/env bash
set -e

# Dependency Verification
if ! command -v make &> /dev/null; then
    echo -e "\033[1;31m[ERROR] 'make' is not installed.\033[0m"
    exit 1
fi
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
    cd "$MERLIN_HOME"
fi

echo -e "\033[1;36m[BUILD] Compiling Merlin Engine...\033[0m"
make

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
fi

if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "$MERLIN_HOME/bin" "$SHELL_PROFILE"; then
        echo -e "\n# Merlin Build Engine" >> "$SHELL_PROFILE"
        echo -e "export PATH=\"\$PATH:$MERLIN_HOME/bin\"" >> "$SHELL_PROFILE"
        echo -e "\033[1;32m[SUCCESS] Added Merlin to $SHELL_PROFILE.\033[0m"
    fi
else
    echo -e "\033[1;33m[WARNING] Could not locate .bashrc or .zshrc. Please manually add $MERLIN_HOME/bin to your PATH.\033[0m"
fi

echo -e "\033[1;32m[SUCCESS] Merlin Engine successfully initialized!\033[0m"
echo -e "Please restart your terminal or run \033[1;36msource $SHELL_PROFILE\033[0m to wield 'merlin'."

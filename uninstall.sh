#!/bin/bash
set -e

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

INSTALL_DIR="${HOME}/.dev-sandbox"

if [ ! -d "$INSTALL_DIR" ]; then
  echo ""
  echo "  ⚠️  ${YELLOW}Not installed${RESET} — ${CYAN}${INSTALL_DIR}${RESET} not found."
  echo ""
  exit 0
fi

echo ""
echo "${BOLD}🗑️  Uninstalling dev-sandbox${RESET}"
echo ""

read -r -p "  ❓ Remove ${INSTALL_DIR}? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo ""
  echo "  Removing ${CYAN}${INSTALL_DIR}${RESET}..."
  rm -rf "$INSTALL_DIR"
  echo "  ${GREEN}✅ Removed successfully${RESET}"
  echo ""
  echo "  ${YELLOW}⚠️  Remember to remove the following line from your ${CYAN}.bashrc${RESET}${YELLOW} or ${CYAN}.zshrc${RESET}${YELLOW}:${RESET}"
  echo ""
  echo "    ${CYAN}export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\"${RESET}"
  echo ""
else
  echo ""
  echo "  ❌ Aborted."
  echo ""
fi

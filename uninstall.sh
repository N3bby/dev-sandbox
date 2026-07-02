#!/bin/bash
set -e

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

INSTALL_DIR="${HOME}/.dev-sandbox"

# Nothing to do if the install dir isn't there; report and exit cleanly.
exit_if_not_installed() {
  if [ ! -d "$INSTALL_DIR" ]; then
    echo ""
    echo "  ⚠️  ${YELLOW}Not installed${RESET} — ${CYAN}${INSTALL_DIR}${RESET} not found."
    echo ""
    exit 0
  fi
}

# Prompt for confirmation, then remove the install dir and print cleanup notes.
confirm_and_remove() {
  local confirm
  read -r -p "  ❓ Remove ${INSTALL_DIR}? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  ❌ Aborted."
    echo ""
    return
  fi

  echo ""
  echo "  Removing ${CYAN}${INSTALL_DIR}${RESET}..."
  rm -rf "$INSTALL_DIR"
  echo "  ${GREEN}✅ Removed successfully${RESET}"
  echo ""
  echo "  ${YELLOW}⚠️  Remember to remove the following line from your ${CYAN}.bashrc${RESET}${YELLOW} or ${CYAN}.zshrc${RESET}${YELLOW}:${RESET}"
  echo ""
  echo "    ${CYAN}export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\"${RESET}"
  echo ""
}

main() {
  exit_if_not_installed

  echo ""
  echo "${BOLD}🗑️  Uninstalling dev-sandbox${RESET}"
  echo ""

  confirm_and_remove
}

main "$@"

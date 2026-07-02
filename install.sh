#!/bin/bash
set -e

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

INSTALL_DIR="${HOME}/.dev-sandbox"
MOUNTS_FILE="${INSTALL_DIR}/mounts"

make_dev_executable() {
  echo "  ${BOLD}[1/2]${RESET} Making dev command executable..."
  chmod +x "${INSTALL_DIR}/bin/dev"
  echo "        ${GREEN}✅ Done${RESET}"
  echo ""
}

# Create a default mounts config on first install; never clobber an existing one.
setup_mounts_config() {
  echo "  ${BOLD}[2/2]${RESET} Setting up mounts config..."
  if [ ! -f "$MOUNTS_FILE" ]; then
    cat > "$MOUNTS_FILE" <<'EOF'
# dev-sandbox mount config — one per line: source:target[:opts]
# opts (comma-separated): ro = read-only, mkdir = create missing dir,
#   touch = create missing empty file, json = create/seed missing or empty file with {}
/var/run/docker.sock:/var/run/docker.sock
~/.ssh/id_rsa:/home/ubuntu/.ssh/id_rsa:ro
~/.ssh/id_rsa.pub:/home/ubuntu/.ssh/id_rsa.pub:ro
~/.gitconfig:/home/ubuntu/.gitconfig:ro
~/.dev-sandbox/agents/claude/config:/home/ubuntu/.claude:mkdir
~/.dev-sandbox/agents/claude/claude.json:/home/ubuntu/.claude.json:json
~/.dev-sandbox/agents/opencode/config:/home/ubuntu/.config/opencode:mkdir
~/.dev-sandbox/agents/opencode/data:/home/ubuntu/.local/share/opencode:mkdir
EOF
    echo "        ${GREEN}✅ Created:${RESET} ${CYAN}${MOUNTS_FILE}${RESET}"
  else
    echo "        ${YELLOW}⏭️  Kept existing:${RESET} ${CYAN}${MOUNTS_FILE}${RESET}"
  fi
}

print_next_steps() {
  echo ""
  echo "${BOLD}🎉 Installation complete!${RESET}"
  echo ""
  echo "  Add the following to your ${CYAN}.bashrc${RESET} or ${CYAN}.zshrc${RESET}:"
  echo ""
  echo "    ${CYAN}export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\"${RESET}"
  echo ""
}

main() {
  echo ""
  echo "${BOLD}🚀 Installing dev-sandbox${RESET}"
  echo ""

  make_dev_executable
  setup_mounts_config
  print_next_steps
}

main "$@"

#!/bin/bash
set -e

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

INSTALL_DIR="${HOME}/.dev-sandbox"
MOUNTS_FILE="${INSTALL_DIR}/mounts"

echo ""
echo "${BOLD}🚀 Installing dev-sandbox${RESET}"
echo ""

echo "  ${BOLD}[1/2]${RESET} Making dev command executable..."
chmod +x "${INSTALL_DIR}/bin/dev"
echo "        ${GREEN}✅ Done${RESET}"
echo ""

echo "  ${BOLD}[2/2]${RESET} Setting up mounts config..."
if [ ! -f "$MOUNTS_FILE" ]; then
  cat > "$MOUNTS_FILE" <<'EOF'
# dev-sandbox mount config — one mount per line: source:target[:ro]
/var/run/docker.sock:/var/run/docker.sock
~/.ssh/id_rsa:/home/ubuntu/.ssh/id_rsa:ro
~/.ssh/id_rsa.pub:/home/ubuntu/.ssh/id_rsa.pub:ro
~/.gitconfig:/home/ubuntu/.gitconfig:ro
~/.claude:/home/ubuntu/.claude
~/.claude.json:/home/ubuntu/.claude.json
EOF
  echo "        ${GREEN}✅ Created:${RESET} ${CYAN}${MOUNTS_FILE}${RESET}"
else
  echo "        ${YELLOW}⏭️  Kept existing:${RESET} ${CYAN}${MOUNTS_FILE}${RESET}"
fi

echo ""
echo "${BOLD}🎉 Installation complete!${RESET}"
echo ""
echo "  Add the following to your ${CYAN}.bashrc${RESET} or ${CYAN}.zshrc${RESET}:"
echo ""
echo "    ${CYAN}export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\"${RESET}"
echo ""

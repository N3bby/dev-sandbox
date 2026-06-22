#!/usr/bin/env zsh
set -e

INSTALL_DIR="${HOME}/.dev-sandbox"
MOUNTS_FILE="${INSTALL_DIR}/mounts"

chmod +x "${INSTALL_DIR}/bin/dev"

# --- Create default mounts file if absent ---
if [ ! -f "$MOUNTS_FILE" ]; then
  cat > "$MOUNTS_FILE" <<'EOF'
# dev-sandbox mount config — one mount per line: source:target[:ro]
/var/run/docker.sock:/var/run/docker.sock
~/.ssh/id_rsa:/root/.ssh/id_rsa:ro
~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:ro
~/.gitconfig:/root/.gitconfig:ro
~/.claude:/root/.claude
~/.claude.json:/root/.claude.json
EOF
  echo "Created: ${MOUNTS_FILE}"
else
  echo "Kept existing: ${MOUNTS_FILE}"
fi

# --- Prompt to add to PATH ---
echo ""
echo "Add the following to your .zshrc to use the dev command:"
echo ""
echo "  export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\""
echo ""
echo "Done."

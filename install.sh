#!/bin/bash
set -e

REPO="git@github.com:n3bby/dev-sandbox.git"
INSTALL_DIR="${HOME}/.dev-sandbox"
MOUNTS_FILE="${INSTALL_DIR}/mounts"

# --- Clone or update repo ---
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating: pulling latest changes..."
  git -C "$INSTALL_DIR" pull
else
  echo "Installing to ${INSTALL_DIR}..."
  git clone "$REPO" "$INSTALL_DIR"
fi

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
echo "Add the following to your .bashrc or .zshrc to use the dev command:"
echo ""
echo "  export PATH=\"\$HOME/.dev-sandbox/bin:\$PATH\""
echo ""
echo "Done."

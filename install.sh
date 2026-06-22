#!/bin/bash
set -e

REPO="git@github.com:n3bby/dev-sandbox.git"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/dev-sandbox"
MOUNTS_FILE="${CONFIG_DIR}/mounts"

# --- Install dev script ---
mkdir -p "$BIN_DIR"
git archive --remote="$REPO" HEAD dev | tar -xO > "${BIN_DIR}/dev"
chmod +x "${BIN_DIR}/dev"
echo "Installed: ${BIN_DIR}/dev"

# --- Warn if not on PATH ---
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  echo "Warning: ${BIN_DIR} is not in your PATH. Add the following to your shell profile:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- Create config dir and default mounts file ---
mkdir -p "$CONFIG_DIR"
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
  echo "Created:   ${MOUNTS_FILE}"
else
  echo "Kept existing: ${MOUNTS_FILE}"
fi

echo ""
echo "Done. Run 'dev' from any project directory to start a sandbox container."

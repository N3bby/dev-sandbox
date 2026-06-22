#!/bin/bash
set -e

BIN="${HOME}/.local/bin/dev"
CONFIG_DIR="${HOME}/.config/dev-sandbox"

if [ -f "$BIN" ]; then
  rm "$BIN"
  echo "Removed: ${BIN}"
else
  echo "Not found: ${BIN}"
fi

if [ -d "$CONFIG_DIR" ]; then
  read -r -p "Remove config directory ${CONFIG_DIR}? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    echo "Removed: ${CONFIG_DIR}"
  else
    echo "Kept: ${CONFIG_DIR}"
  fi
fi

echo ""
echo "Done."

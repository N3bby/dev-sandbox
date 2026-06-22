#!/bin/bash
set -e

INSTALL_DIR="${HOME}/.dev-sandbox"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Not installed (${INSTALL_DIR} not found)."
  exit 0
fi

read -r -p "Remove ${INSTALL_DIR}? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  rm -rf "$INSTALL_DIR"
  echo "Removed: ${INSTALL_DIR}"
  echo "Also remove the PATH entry from your .bashrc or .zshrc."
else
  echo "Aborted."
fi

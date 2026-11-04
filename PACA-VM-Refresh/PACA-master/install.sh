#!/usr/bin/env sh
set -eu

REPO="prometheus-lua/Prometheus"
INSTALL_BASE="${PROMETHEUS_LUA_HOME:-$HOME/.local/share/prometheus-lua}"
BIN_DIR="${PROMETHEUS_LUA_BIN:-$HOME/.local/bin}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

fetch() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi
  echo "Neither curl nor wget is installed." >&2
  exit 1
}

need_cmd tar
need_cmd uname
need_cmd mktemp
need_cmd grep
need_cmd sed

OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Linux) OS="linux" ;;
  Darwin) OS="macos" ;;
  *)
    echo "Unsupported operating system: $OS_NAME" >&2
    exit 1
    ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

LATEST_JSON="$TMP_DIR/latest.json"
fetch "https://api.github.com/repos/$REPO/releases/latest" "$LATEST_JSON"

TAG="$(grep '"tag_name":' "$LATEST_JSON" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)"
if [ -z "$TAG" ]; then
  echo "Failed to resolve latest release tag." >&2
  exit 1
fi

ASSET="prometheus-lua-$TAG-$OS.tar.gz"
ASSET_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
ARCHIVE_PATH="$TMP_DIR/$ASSET"

fetch "$ASSET_URL" "$ARCHIVE_PATH"

mkdir -p "$INSTALL_BASE" "$BIN_DIR"

tar -xzf "$ARCHIVE_PATH" -C "$INSTALL_BASE"
TARGET_DIR="$INSTALL_BASE/prometheus-lua-$TAG-$OS"
if [ ! -d "$TARGET_DIR" ]; then
  echo "Unexpected archive layout; missing $TARGET_DIR" >&2
  exit 1
fi

ln -sfn "$TARGET_DIR/prometheus-lua" "$BIN_DIR/prometheus-lua"
chmod +x "$TARGET_DIR/prometheus-lua"

printf 'Installed prometheus-lua %s to %s\n' "$TAG" "$TARGET_DIR"
printf 'Linked command: %s/prometheus-lua\n' "$BIN_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    ;;
  *)
    printf 'Add %s to PATH, e.g.: export PATH="%s:$PATH"\n' "$BIN_DIR" "$BIN_DIR"
    ;;
esac
#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <linux|macos> [version]" >&2
  exit 1
fi

OS="$1"
VERSION="${2:-${GITHUB_REF_NAME:-}}"

if [ -z "$VERSION" ]; then
  VERSION="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [ -z "$VERSION" ]; then
  echo "Version is required (pass as arg or run from a tagged commit)." >&2
  exit 1
fi

case "$OS" in
  linux|macos) ;;
  *)
    echo "Unsupported OS '$OS'. Use linux or macos." >&2
    exit 1
    ;;
esac

DIST_DIR="dist"
PKG_DIR="$DIST_DIR/prometheus-lua-$VERSION-$OS"
ARCHIVE="$DIST_DIR/prometheus-lua-$VERSION-$OS.tar.gz"

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
mkdir -p "$PKG_DIR/runtime"

cp -R src "$PKG_DIR/"
cp cli.lua "$PKG_DIR/"
cp LICENSE README.md "$PKG_DIR/"
cp prometheus-lua "$PKG_DIR/"

RUNTIME_BIN="${PROMETHEUS_BUNDLED_LUA:-}"
if [ -z "$RUNTIME_BIN" ]; then
  if command -v luajit >/dev/null 2>&1; then
    RUNTIME_BIN="$(command -v luajit)"
  elif command -v lua5.1 >/dev/null 2>&1; then
    RUNTIME_BIN="$(command -v lua5.1)"
  elif command -v lua >/dev/null 2>&1; then
    RUNTIME_BIN="$(command -v lua)"
  else
    echo "No Lua runtime available to bundle. Install luajit/lua5.1 or set PROMETHEUS_BUNDLED_LUA." >&2
    exit 1
  fi
fi

cp "$RUNTIME_BIN" "$PKG_DIR/runtime/lua"
chmod +x "$PKG_DIR/runtime/lua"

# Inject release version into the packaged launcher without relying on git metadata at runtime.
sed -i.bak "s/PROMETHEUS_LUA_VERSION:=dev/PROMETHEUS_LUA_VERSION:=$VERSION/" "$PKG_DIR/prometheus-lua"
rm -f "$PKG_DIR/prometheus-lua.bak"
chmod +x "$PKG_DIR/prometheus-lua"

mkdir -p "$DIST_DIR"
tar -czf "$ARCHIVE" -C "$DIST_DIR" "prometheus-lua-$VERSION-$OS"

echo "Created $ARCHIVE"

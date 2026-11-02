#!/usr/bin/env bash
# Exercise the extracted archive outside the repository, using its bundled Lua.
set -euo pipefail

os="${1:?Usage: smoke-test.sh <linux|macos> <version>}"
version="${2:?Usage: smoke-test.sh <linux|macos> <version>}"
archive="$PWD/dist/prometheus-lua-$version-$os.tar.gz"
smoke_dir="$(mktemp -d)"
trap 'rm -rf "$smoke_dir"' EXIT
tar -xzf "$archive" -C "$smoke_dir"
cd "$smoke_dir"
package="$smoke_dir/prometheus-lua-$version-$os"
test -x "$package/runtime/lua"
test -x "$package/prometheus-lua"
unset PROMETHEUS_LUA_VERSION
test "$("$package/prometheus-lua" --version)" = "$version"
"$package/prometheus-lua" --help > /dev/null
printf 'local sum = 0; for i = 1, 10 do sum = sum + i end; print(sum)\n' > input.lua
"$package/prometheus-lua" --preset Minify --Lua51 --out output.lua input.lua
test -s output.lua
test "$("$package/runtime/lua" output.lua)" = '55'
echo "Release archive smoke test passed ($os, $version)."

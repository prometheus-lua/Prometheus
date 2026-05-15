# Installation

## Linux and macOS (recommended)

Install latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh | sh
```

Verify installation:

```bash
prometheus-lua --version
```

Update later:

```bash
prometheus-lua update
```

The release bundle includes a Lua runtime (`runtime/lua`), so you do not need a separate Lua install for packaged CLI usage.

## From source

```bash
git clone https://github.com/prometheus-lua/Prometheus.git
cd Prometheus
lua ./cli.lua --version
```

Then run obfuscation:

```bash
lua ./cli.lua --preset Medium ./your_file.lua
```

For source usage, Prometheus expects a Lua runtime (LuaJIT, `lua5.1`, or `lua`).

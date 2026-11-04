# Using Prometheus as a Library

Prometheus can be required directly from Lua.

## In this repository

```lua
local Prometheus = require("src.prometheus")

local code = 'print("Hello")'
local pipeline = Prometheus.Pipeline:fromConfig(Prometheus.Presets.Medium)
local out = pipeline:apply(code, "inline-source.lua")
print(out)
```

## Integration in another project

Copy the `src/` tree and make sure `require` can resolve `src.prometheus` (or adapt your `package.path` to where `prometheus.lua` is located).

## Useful runtime controls

Disable noisy logs:

```lua
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
```

Enable syntax highlighting in unparser output:

```lua
local pipeline = Prometheus.Pipeline:new({
  LuaVersion = "Lua51",
  PrettyPrint = false,
  Highlight = true,
})
```

## Notes

- `pipeline:apply` expects source code text.
- If `apply` is called with no filename, logs use `Anonymous Script`.

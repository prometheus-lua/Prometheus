---
description: Prometheus is a Lua obfuscator written in pure Lua.
---

# Prometheus Documentation

Prometheus obfuscates Lua source code using AST transforms and a configurable pipeline.

Use the [Prometheus Playground](https://prometheus-lua.github.io/Prometheus/) to quickly try out settings and test small snippets. For larger scripts and advanced workflows, use the CLI (`prometheus-lua` or `cli.lua`).

This documentation covers:

- CLI usage (`prometheus-lua` and `cli.lua`)
- configuration and presets
- all built-in obfuscation steps
- embedding Prometheus as a library

## Who this is for

- Lua developers shipping scripts where source readability is a concern
- users integrating Prometheus in build pipelines
- developers embedding Prometheus into another Lua application

## Supported language targets

- Lua 5.1 (`Lua51`)
- LuaU (`LuaU`)

## Read in this order

1. Installation
2. Quickstart
3. CLI Usage
4. Presets
5. Custom Config
6. Step Reference

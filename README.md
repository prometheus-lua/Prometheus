<div align="center">

<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&height=180&color=gradient&text=Prometheus&fontAlign=50&fontAlignY=35&fontSize=42&desc=Lua%20Obfuscator%20%E2%80%A2%20AST%20Transformations%20%E2%80%A2%20Control%20Flow%20Obfuscation&descAlign=50&descAlignY=60" />

<a href="https://github.com/prometheus-lua/Prometheus">
  <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=24&duration=2500&pause=900&center=true&vCenter=true&width=760&lines=Pure+Lua+Obfuscation;AST+Transforms+%E2%80%A2+Encryption+%E2%80%A2+Anti-Tamper;Lua+5.1+and+LuaU+support;Built+for+code+protection" alt="Typing SVG" />
</a>

<br/>

<a href="https://prometheus-lua.github.io/Prometheus/">
  <img src="https://img.shields.io/badge/Playground-Try%20Out-0F766E?style=for-the-badge&logo=github&logoColor=white" alt="Open Prometheus Playground" />
</a>
<a href="https://github.com/prometheus-lua/Prometheus/actions/workflows/Test.yml">
  <img src="https://img.shields.io/github/actions/workflow/status/prometheus-lua/Prometheus/Test.yml?branch=master&style=for-the-badge&label=Tests" alt="Tests" />
</a>
<a href="https://github.com/prometheus-lua/Prometheus/stargazers">
  <img src="https://img.shields.io/github/stars/prometheus-lua/Prometheus?style=for-the-badge&logo=github&label=Stars" alt="GitHub stars" />
</a>
<a href="https://discord.gg/U8h4d4Rf64">
  <img src="https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord server" />
</a>

</div>

---

<p align="center">
  <img src="assets/readme/obfuscation-preview.gif" alt="Prometheus obfuscation process preview" width="900" />
</p>

**Prometheus** is a Lua obfuscator written in pure Lua.

It applies a range of **AST-based transformations** to make source code significantly harder to read, analyze, and reverse engineer.  
These include techniques such as **control-flow flattening**, **constant encryption**, and other Lua-specific obfuscation strategies.

The project was inspired by the excellent [javascript-obfuscator](https://github.com/javascript-obfuscator/javascript-obfuscator).

Currently, Prometheus supports:

- **Lua 5.1**
- **LuaU** *(basic support is available, but still not fully finished)*

---


## Quick Start

Try the browser version first:


<a href="https://prometheus-lua.github.io/Prometheus/">
  <img src="https://img.shields.io/badge/Playground-Try%20Out-0F766E?style=for-the-badge&logo=github&logoColor=white" alt="Open Prometheus Playground" />
</a>

### Install CLI (Linux/macOS)

Install latest release with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh | sh
```

Then use the CLI directly:

```bash
prometheus-lua --version
prometheus-lua --preset Medium ./your_file.lua
```

The release bundle includes a Lua runtime, so no separate Lua install is required for the packaged CLI.

To update to the latest release:

```bash
prometheus-lua update
```

To uninstall:
```bash
rm -f ~/.local/bin/prometheus-lua && rm -rf ~/.local/share/prometheus-lua
```

### Local source usage

```bash
git clone https://github.com/prometheus-lua/Prometheus.git
cd Prometheus
lua cli.lua --preset Medium ./your_file.lua
```

---

## Documentation

You can find the full documentation, including the getting started guide, here:

<p align="center">
  <a href="https://prometheus-lua.github.io/Prometheus/docs/">
    <img src="https://img.shields.io/badge/Documentation-Read%20the%20Docs-111111?style=for-the-badge&logo=readthedocs&logoColor=white" alt="Documentation" />
  </a>
</p>

Contribution guidelines: [CONTRIBUTING.md](CONTRIBUTING.md)

---

### Requirements

Packaged CLI releases include a bundled Lua runtime.
For source usage, Prometheus requires **LuaJIT** or **Lua 5.1+**.

Lua 5.1 binaries can be downloaded here:  
https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/

---

## Example

### Input

```lua
-- input.lua
print("Hello, World!");
```

### Obfuscated output

```lua
-- input.obfuscated.lua
return(function(...)local L={"afT6mf1V","/7mJXsuvmE1c/fT3";"tn1ZSn6=","37ghSJM=";"WqermfWAWuuZpb3XX7M=","tqXGSJ3u","XQXpL9x21dxAWJa//p==","SrM=";"3q+5SJM=","/D==";"t7XUt0p=";"mIeOmIx9";"LdgrBfWdWuNABsb+KJxj","SJWJ4dahKsebW7t+KQv=","/cDu3AvP/D==";"Llv7uD==","tJWhFfTE";"TQ43ctIuy9HIop==","mEu93p==";"WJax1sXEXEaxWuxGt6==","t0gPSEp=",...
-- remaining obfuscated output omitted
```

For more advanced use cases, configuration, and presets, see the [documentation](https://prometheus-lua.github.io/Prometheus/docs/).

---

## Tests

To run the Prometheus test suite:

```bash
lua ./tests.lua [--Linux]
```

---

## Community

Prometheus has an official Discord server:

<p align="center">
  <a href="https://discord.gg/U8h4d4Rf64">
    <img src="https://img.shields.io/badge/Join%20the%20Discord%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Join Discord" />
  </a>
</p>

---

## License and Commercial Use

Prometheus is licensed under the **Prometheus License**, a modified MIT-style license.

You are free to use, modify, and distribute this software, including for commercial purposes, under the following conditions:

- Any commercial product, wrapper, or service *(including SaaS or hosted solutions)* that uses or integrates Prometheus must include clear attribution to:

```text
Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus
```

- The attribution must be visible in the product’s:
  - UI
  - documentation
  - public website
- The obfuscated output files generated by Prometheus do **not** need to include any license or copyright notice.
- Derivative works and public forks must also include a statement in their README noting that they are based on Prometheus.

Full license text: [Prometheus License](https://github.com/prometheus-lua/Prometheus/blob/master/LICENSE)

---

<div align="center">

<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&height=120&section=footer&color=gradient" />

</div>

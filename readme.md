# :fire: Prometheus
## Description
Prometheus is a Lua obfuscator written in pure Lua.

This Project was inspired by the amazing [javascript-obfuscator](https://github.com/javascript-obfuscator/javascript-obfuscator).   
It can currently obfuscate Lua51 and Roblox's LuaU, however LuaU support is not finished yet.

You can find the full Documentation including a getting started guide [here](https://levno-710.gitbook.io/prometheus/).

## Installation
To install Prometheus, simply clone the Github Repository using:

```batch
git clone https://github.com/Levno710/Prometheus.git
```

Alternatively you can download the Sources [here](https://github.com/Levno710/Prometheus/archive/refs/heads/master.zip).

Prometheus also Requires LuaJIT or Lua51 in order to work. The Lua51 binaries can be downloaded [here](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/).
## Usage
Prometheus provides a simple cli for obfuscating scripts. It can be used as following:
```batch
lua ./cli.lua [options] ./your_file.lua
```
## Tests
To perform the Prometheus Tests, just run
```batch
lua ./tests.lua
```
## Credits
### Contributors
- [levno-710](https://github.com/levno-710)
### Libraries Used
- [lua-bit-numberlua](https://github.com/davidm/lua-bit-numberlua)
## License
This Project is Licensed under the GNU General Public License v3.0. For more details, please refer to [LICENSE](https://github.com/levno-710/Prometheus/blob/master/LICENSE).
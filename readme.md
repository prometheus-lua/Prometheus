# :fire: Prometheus
## Description
Prometheus is a Lua obfuscator written in pure Lua.

This Project was inspired by the amazing [javascript-obfuscator](https://github.com/javascript-obfuscator/javascript-obfuscator).   
It can currently obfuscate Lua51 and Roblox's LuaU, however LuaU support is not finished yet.

You can find the full Documentation including a getting started guide [here](https://levno-710.gitbook.io/prometheus/).

## Installation
To install Prometheus, simply clone the Github Repository using:

```batch
git clone https://github.com/levno-710/Prometheus.git
```

Alternatively you can download the Sources [here](https://github.com/levno-710/Prometheus/archive/refs/heads/master.zip).

Prometheus also Requires LuaJIT or Lua51 in order to work. The Lua51 binaries can be downloaded [here](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/).

## Usage
To quickly obfuscate a script:
```batch
lua ./cli.lua --preset Medium ./your_file.lua
```
When using the windows release:
```batch
prometheus.exe --preset Medium ./your_file.lua
```
For more advanced use cases see the [Documentation](https://levno-710.gitbook.io/prometheus/).
## Tests
To perform the Prometheus Tests, just run
```batch
lua ./tests.lua
```
## Building
Prometheus can currently only be build for and on Windows.
It requires [srlua.exe](https://github.com/LuaDist/srlua) and [glue.exe](https://github.com/LuaDist/srlua) inside of the root directory. If lua51 was linked dynamically, lua51.dll must also be present. Then Prometheus for Windows can be built using
```batch
build.bat
```
This creates a folder named build, that contains prometheus.exe as well as everything that is needed in order to run Prometheus.   
Then
```batch
prometheus.exe [options]
```
can be used instead of
```batch
lua ./cli.lua [options]
```
## Credits
### Contributors
- [levno-710](https://github.com/levno-710)
- [brandonsturgeon](https://github.com/brandonsturgeon)
- [pnlmon](https://github.com/pnlmon)
- [britzl](https://github.com/britzl)
- [SpinnySpiwal](https://github.com/SpinnySpiwal)
- [oxince](https://github.com/oxince)
## License
This Project is Licensed under the GNU General Public License v3.0. For more details, please refer to [LICENSE](https://github.com/levno-710/Prometheus/blob/master/LICENSE).

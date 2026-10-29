local presets = require('src.presets')
local configs = {}
for _, name in ipairs({'Minify', 'Cff', 'Vmify', 'Weak', 'Medium', 'Strong'}) do
    local config = presets[name]
    config.Name = name
    config.LuaVersion = 'LuaU'
    configs[#configs + 1] = config
end
return configs

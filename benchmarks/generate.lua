-- Generate the actual preset, including AntiTamper, and report compiler CPU time.
local Prometheus = require('src.prometheus')
local presets = require('src.presets')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local preset, seed, input, output = unpack(arg)
local file = assert(io.open(input, 'rb'))
local source = file:read('*a')
file:close()
local config = {}
for key, value in pairs(assert(presets[preset])) do config[key] = value end
config.Seed = assert(tonumber(seed))
local start = os.clock()
local generated = Prometheus.Pipeline:fromConfig(config):apply(source, input)
local elapsed = os.clock() - start
file = assert(io.open(output, 'wb'))
file:write(generated)
file:close()
print(string.format('%.9f', elapsed))

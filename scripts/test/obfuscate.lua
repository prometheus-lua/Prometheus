-- Run in a separate process so parser/compiler hangs cannot stop the suite.
local lib = require("scripts.test.lib")
local Prometheus = require("src.prometheus")
local presets = require("src.presets")
local config_path, preset, seed, input, output = unpack(arg)
local config
if config_path ~= "" then
    local loaded = assert(loadfile(config_path))()
    config = type(loaded[1]) == "table" and loaded[tonumber(preset)] or loaded
else
    config = assert(presets[preset])
end
local cfg = {}
for k, v in pairs(config) do cfg[k] = v end
cfg.Seed = assert(tonumber(seed))
cfg.Steps = {}
for _, step in ipairs(config.Steps) do
    if step.Name ~= "AntiTamper" then cfg.Steps[#cfg.Steps + 1] = step end
end
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local pipeline = Prometheus.Pipeline:fromConfig(cfg)
pipeline:setNameGenerator("MangledShuffled")
local code = lib.read(input)
if code:sub(1, 1) == "#" then code = code:gsub("^[^\n]*", "", 1) end
lib.write(output, pipeline:apply(code, input))

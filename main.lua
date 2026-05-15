-- Run this in the CLI is lua5.1.exe. Do not use any newer verions, or LUAJIT.
-- .\lua5.1.exe .\main.lua

local Prometheus = require("src/prometheus")

local source_file = io.open("input.lua", "r")

if not source_file then print("No Source detected") return end

local code = source_file:read("*a")

source_file:close()

local pipeline = Prometheus.Pipeline:fromConfig(Prometheus.Presets["MainScript"])

local temp = pipeline:apply(code)
local output_temp = io.open("Output_code.luau", "w")

output_temp:write(temp)

output_temp:close()
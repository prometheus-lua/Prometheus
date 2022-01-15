-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- prometheus.lua
-- This file is the entrypoint for Prometheus

-- Configure package.path for require
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end

local oldPkgPath = package.path;
package.path = script_path() .. "?.lua;" .. package.path;

-- Require Prometheus Submodules
local Pipeline  = require("prometheus.pipeline");
local highlight = require("highlightlua");
local colors    = require("colors");
local Logger    = require("logger");
local Presets   = require("presets");
local Config    = require("config");
local util      = require("prometheus.util");

-- Restore package.path
package.path = oldPkgPath;

-- Export
return {
    Pipeline  = Pipeline;
    colors    = colors;
    Config    = util.readonly(Config); -- Readonly
    Logger    = Logger;
    highlight = highlight;
    Presets   = Presets;
}


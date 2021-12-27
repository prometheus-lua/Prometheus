-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- prometheus.lua
-- This file exports all prometheus exports

-- Configure Path for Require
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end

package.path = script_path() .. "?.lua;" .. package.path;

-- Require Prometheus Submodules
local Pipeline  = require("obfuscator.pipeline");
local highlight = require("highlightlua");
local colors    = require("colors");
local Logger    = require("logger");

-- Export
return {
    Pipeline = Pipeline;
    colors   = colors;
    Logger   = Logger;
    highlight = highlight;
}
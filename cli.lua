-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- test.lua
-- This script contains the Code for the Prometheus CLI

-- Configure package.path for requiring Prometheus
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end
package.path = script_path() .. "?.lua;" .. package.path;
local Prometheus = require("src.prometheus");
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info;

-- see if the file exists
local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
  end
  
-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
local function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do 
      lines[#lines + 1] = line
    end
    return lines
  end

-- CLI
local config;
local sourceFile;
local outFile;

-- Parse Arguments
local i = 1;
while i <= #arg do
    local curr = arg[i];
    if curr:sub(1, 2) == "--" then
        if curr == "--preset" or curr == "--p" then
            if config then
                Prometheus.Logger:warn("The config was set multiple times");
            end

            i = i + 1;
            local preset = Prometheus.Presets[arg[i]];
            if not preset then
                Prometheus.Logger:error(string.format("A Preset with the name \"%s\" was not found!", tostring(arg[i])));
            end

            config = preset;
        elseif curr == "--config" or curr == "--c" then
            i = i + 1;
            local filename = tostring(arg[i]);
            if not file_exists(filename) then
                Prometheus.Logger:error(string.format("The config file \"%s\" was not found!", filename));
            end

            local content = table.concat(lines_from(filename), "\n");
            -- Load Config from File
            local func = loadstring(content);
            -- Sandboxing
            setfenv(func, {});
            config = func();
        elseif curr == "--out" or curr == "--o" then
            i = i + 1;
            if(outFile) then
                Prometheus.Logger:warn("The output file was specified multiple times!");
            end
            outFile = arg[i];
        else
            Prometheus.Logger:warn(string.format("The option \"%s\" is not valid and therefore ignored"));
        end
    else
        if sourceFile then
            Prometheus.Logger:error(string.format("Unexpected argument \"%s\"", arg[i]));
        end
        sourceFile = tostring(arg[i]);
    end
    i = i + 1;
end

if not config then
    Prometheus.Logger:warn("No config was specified, falling back to Minify preset");
    config = Prometheus.Presets.Minify;
end

if not file_exists(sourceFile) then
    Prometheus.Logger:error(string.format("The File \"%s\" was not found!", sourceFile));
end

if not outFile then
    if sourceFile:sub(-4) == ".lua" then
        outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua";
    else
        outFile = sourceFile .. ".obfuscated.lua";
    end
end

print(sourceFile);
print(outFile);

local source = table.concat(lines_from(sourceFile), "\n");
local pipeline = Prometheus.Pipeline:fromConfig(config);
local out = pipeline:apply(source, sourceFile);
Prometheus.Logger:info(string.format("Writing output to \"%s\"", outFile));

-- Write Output
local handle = io.open(outFile, "w");
handle:write(out);
handle:close();
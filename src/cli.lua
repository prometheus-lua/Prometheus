-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- cli.lua
--
-- This Script contains the Code for the Prometheus CLI.

-- Configure package.path for requiring Prometheus.
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end
package.path = script_path() .. "?.lua;" .. package.path

local INSTALL_SCRIPT_URL = "https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh"

local function run_shell(command)
	local ok = os.execute(command)
	if type(ok) == "number" then
		return ok == 0
	end
	if type(ok) == "boolean" then
		return ok
	end
	return false
end

local function get_version()
	local version = os.getenv("PROMETHEUS_LUA_VERSION")
	if version and version ~= "" then
		return version
	end
	return "dev"
end

local function print_help()
	print("Prometheus Lua CLI")
	print("Usage: prometheus-lua [command] [options] <input.lua>")
	print("")
	print("Commands:")
	print("  update                 Install latest release via installer script")
	print("  --version, -v          Print CLI version")
	print("")
	print("Obfuscation options:")
	print("  --preset, --p <name>   Use preset (e.g. Minify, Medium, Strong)")
	print("  --config, --c <file>   Use custom config Lua file")
	print("  --out, --o <file>      Set output path")
	print("  --lua51                Force Lua 5.1 target")
	print("  --luau                 Force Luau target")
	print("  --pretty               Pretty print output")
	print("  --nocolors             Disable colored logs")
	print("  --saveerrors           Persist parser errors to file")
	print("")
	print("Command, option, and preset names are case-insensitive; paths keep their original case.")
	print("Options with a value also accept --option=value. Use -- before an input starting with '-'.")
end

local function run_update()
	local command
	if run_shell("command -v curl >/dev/null 2>&1") then
		command = string.format("curl -fsSL '%s' | sh", INSTALL_SCRIPT_URL)
	elseif run_shell("command -v wget >/dev/null 2>&1") then
		command = string.format("wget -qO- '%s' | sh", INSTALL_SCRIPT_URL)
	else
		io.stderr:write("Neither curl nor wget was found. Please install one of them and retry.\n")
		os.exit(1)
	end

	print("Updating prometheus-lua using official installer")
	if not run_shell(command) then
		io.stderr:write("Update failed\n")
		os.exit(1)
	end

	print("Update completed")
end

local firstArg = arg[1] and arg[1]:lower()
if firstArg == "update" then
	run_update()
	os.exit(0)
end
if firstArg == "--version" or firstArg == "-v" then
	print(get_version())
	os.exit(0)
end

if firstArg == "--help" or firstArg == "-h" or firstArg == "help" then
	print_help()
	os.exit(0)
end

---@diagnostic disable-next-line: different-requires
local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info
Prometheus.Logger.errorCallback = function(...)
	local args = { ... }
	local message = table.concat(args, " ")
	io.stderr:write(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")
	os.exit(1)
end

-- Check if the file exists
local function file_exists(file)
	local f = io.open(file, "rb")
	if f then
		f:close()
	end
	return f ~= nil
end

string.split = function(str, sep)
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c)
		fields[#fields + 1] = c
	end)
	return fields
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
local function lines_from(file)
	if not file_exists(file) then
		return {}
	end
	local lines = {}
	for line in io.lines(file) do
		lines[#lines + 1] = line
	end
	return lines
end

local function load_chunk(content, chunkName, environment)
	if type(loadstring) == "function" then
		local func, err = loadstring(content, chunkName)
		if not func then
			return nil, err
		end
		if environment and type(setfenv) == "function" then
			setfenv(func, environment)
		elseif environment and type(load) == "function" then
			return load(content, chunkName, "t", environment)
		end
		return func
	end

	if type(load) ~= "function" then
		return nil, "No load function available"
	end

	return load(content, chunkName, "t", environment)
end

local function output_stem(path)
	local base, extension = path:match("^(.*)(%.[^/\\%.]+)$")
	if extension and (extension:lower() == ".lua" or extension:lower() == ".luau") then
		return base, extension
	end
	return path, ".lua"
end

local function find_preset(name)
	local exact = Prometheus.Presets[name]
	if exact then return exact end
	for presetName, preset in pairs(Prometheus.Presets) do
		if presetName:lower() == name:lower() then return preset end
	end
end

local function run_cli()
	local config, sourceFile, outFile, luaVersion, prettyPrint
	local optionsEnabled = true
	Prometheus.colors.enabled = true

	local i = 1
	while i <= #arg do
		local curr = arg[i]
		if optionsEnabled and curr == "--" then
			optionsEnabled = false
		elseif optionsEnabled and #curr > 1 and curr:sub(1, 1) == "-" then
			local option, inlineValue = curr:match("^(%-%-[^=]+)=(.*)$")
			option = (option or curr):lower()

			local function value()
				if inlineValue ~= nil then
					if inlineValue == "" then
						Prometheus.Logger:error(string.format('The option "%s" requires a value', curr))
					end
					return inlineValue
				end
				local nextArg = arg[i + 1]
				if not nextArg or nextArg == "" or nextArg:sub(1, 1) == "-" then
					Prometheus.Logger:error(string.format('The option "%s" requires a value', curr))
				end
				i = i + 1
				return nextArg
			end

			local takesValue = option == "--preset" or option == "--p" or option == "--config"
				or option == "--c" or option == "--out" or option == "--o"
			local isFlag = option == "--help" or option == "-h" or option == "--version" or option == "-v"
				or option == "--nocolors" or option == "--lua51" or option == "--luau"
				or option == "--pretty" or option == "--saveerrors"
			if inlineValue ~= nil and not takesValue and isFlag then
				Prometheus.Logger:error(string.format('The option "%s" does not accept a value', curr))
			end

			if option == "--help" or option == "-h" then
				print_help()
				return
			elseif option == "--version" or option == "-v" then
				print(get_version())
				return
			elseif option == "--preset" or option == "--p" then
				local name = value()
				local preset = find_preset(name)
				if not preset then
					Prometheus.Logger:error(string.format('A preset with the name "%s" was not found!', name))
				end
				if config then Prometheus.Logger:warn("The config was set multiple times") end
				config = {}
				for key, entry in pairs(preset) do config[key] = entry end
			elseif option == "--config" or option == "--c" then
				local filename = value()
				if not file_exists(filename) then
					Prometheus.Logger:error(string.format('The config file "%s" was not found!', filename))
				end
				local content = table.concat(lines_from(filename), "\n")
				local func, err = load_chunk(content, "@" .. filename, {})
				if not func then
					Prometheus.Logger:error(string.format('Failed to parse config file "%s": %s', filename, tostring(err)))
				end
				if config then Prometheus.Logger:warn("The config was set multiple times") end
				config = func()
				if type(config) ~= "table" then
					Prometheus.Logger:error(string.format('The config file "%s" must return a table', filename))
				end
			elseif option == "--out" or option == "--o" then
				local filename = value()
				if outFile then Prometheus.Logger:warn("The output file was specified multiple times!") end
				outFile = filename
			elseif option == "--nocolors" then
				Prometheus.colors.enabled = false
			elseif option == "--lua51" then
				luaVersion = "Lua51"
			elseif option == "--luau" then
				luaVersion = "LuaU"
			elseif option == "--pretty" then
				prettyPrint = true
			elseif option == "--saveerrors" then
				Prometheus.Logger.errorCallback = function(...)
					local message = table.concat({ ... }, " ")
					io.stderr:write(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")
					if sourceFile then
						local stem = output_stem(sourceFile)
						local filename = stem .. ".error.txt"
						local handle, writeError = io.open(filename, "w")
						if handle then
							handle:write(message)
							handle:close()
						else
							io.stderr:write(string.format('Cannot write error file "%s": %s\n', filename, tostring(writeError)))
						end
					end
					os.exit(1)
				end
			else
				Prometheus.Logger:error(string.format('Unknown option "%s"', curr))
			end
		else
			if sourceFile then
				Prometheus.Logger:error(string.format('Unexpected argument "%s"', curr))
			end
			sourceFile = curr
		end
		i = i + 1
	end

	if not sourceFile then
		Prometheus.Logger:error("No input file was specified!")
	end
	if not config then
		Prometheus.Logger:warn("No config was specified, falling back to Minify preset")
		config = {}
		for key, entry in pairs(Prometheus.Presets.Minify) do config[key] = entry end
	end

	config.LuaVersion = luaVersion or config.LuaVersion
	config.PrettyPrint = prettyPrint ~= nil and prettyPrint or config.PrettyPrint

	if not file_exists(sourceFile) then
		Prometheus.Logger:error(string.format('The file "%s" was not found!', sourceFile))
	end
	if not outFile then
		local stem, extension = output_stem(sourceFile)
		outFile = stem .. ".obfuscated" .. extension
	end

	local source = table.concat(lines_from(sourceFile), "\n")
	local pipeline = Prometheus.Pipeline:fromConfig(config)
	local out = pipeline:apply(source, sourceFile)
	Prometheus.Logger:info(string.format('Writing output to "%s"', outFile))

	local handle, writeError = io.open(outFile, "w")
	if not handle then
		Prometheus.Logger:error(string.format('Cannot write output file "%s": %s', outFile, tostring(writeError)))
	end
	handle:write(out)
	handle:close()
end

local ok, err = xpcall(run_cli, function(e)
	return tostring(e)
end)
if not ok then
	local message = tostring(err):gsub("^.-:%d+:%s*", "")
	io.stderr:write(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")
	os.exit(1)
end

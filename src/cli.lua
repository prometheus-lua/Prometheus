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
	print("  trace                  Rewrite a traceback using a source map")
	print("  --version, -v          Print CLI version")
	print("")
	print("Obfuscation options:")
	print("  --preset, --p <name>   Use preset (e.g. Minify, Medium, High)")
	print("  --config, --c <file>   Use custom config Lua file")
	print("  --out, --o <file>      Set output path")
	print("  --source-map <file>   Write a source map for generated output")
	print("  --source-map-no-sources Omit embedded source text from the map")
	print("  --Lua51                Force Lua 5.1 target")
	print("  --LuaU                 Force LuaU target")
	print("  --pretty               Pretty print output")
	print("  --nocolors             Disable colored logs")
	print("  --saveerrors           Persist parser errors to file")
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

if arg[1] == "update" then
	run_update()
	os.exit(0)
end

if arg[1] == "--version" or arg[1] == "-v" then
	print(get_version())
	os.exit(0)
end

if arg[1] == "--help" or arg[1] == "-h" or arg[1] == "help" then
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

local function read_file(file)
	local handle = io.open(file, "rb")
	if not handle then
		return nil
	end
	local content = handle:read("*a")
	handle:close()
	return content
end

local function write_file(file, content)
	local handle, err = io.open(file, "wb")
	if not handle then
		return nil, err
	end
	local ok, writeErr = handle:write(content)
	local closeOk, closeErr = handle:close()
	if not ok then
		return nil, writeErr
	end
	if closeOk == nil then
		return nil, closeErr
	end
	return true
end

local function path_basename(path)
	return (path:gsub("\\", "/"):match("([^/]+)$")) or path
end

local function path_info(path)
	path = (path or ""):gsub("\\", "/")
	local root, rest, absolute = "", path, false
	if path:match("^%a:/") then
		root, rest, absolute = path:sub(1, 2) .. "/", path:sub(4), true
	elseif path:sub(1, 1) == "/" then
		root, rest, absolute = "/", path:sub(2), true
	end
	local parts = {}
	for part in rest:gmatch("[^/]+") do
		if part == "." or part == "" then
			-- Skip redundant path components.
		elseif part == ".." then
			if #parts > 0 and parts[#parts] ~= ".." then
				parts[#parts] = nil
			elseif not absolute then
				parts[#parts + 1] = part
			end
		else
			parts[#parts + 1] = part
		end
	end
	return root, parts, absolute
end

local function normalize_path(path)
	local root, parts, absolute = path_info(path)
	local value = root .. table.concat(parts, "/")
	if value == "" then
		return "."
	end
	if absolute and #parts == 0 then
		return root
	end
	return value
end

local function path_directory(path)
	local normalized = normalize_path(path)
	local directory = normalized:match("^(.*)/[^/]*$")
	if not directory then
		return "."
	elseif directory == "" then
		return "/"
	elseif directory:match("^%a:$") then
		return directory .. "/"
	end
	return directory
end

local function relative_path(fromPath, targetPath)
	local fromRoot, fromParts, fromAbsolute = path_info(fromPath)
	local targetRoot, targetParts, targetAbsolute = path_info(targetPath)
	if fromAbsolute ~= targetAbsolute or fromRoot:lower() ~= targetRoot:lower() then
		return normalize_path(targetPath)
	end
	local common = 0
	while common < #fromParts and common < #targetParts do
		local fromPart, targetPart = fromParts[common + 1], targetParts[common + 1]
		if fromRoot:match("^%a:/$") then
			fromPart, targetPart = fromPart:lower(), targetPart:lower()
		end
		if fromPart ~= targetPart then
			break
		end
		common = common + 1
	end
	local parts = {}
	for _ = common + 1, #fromParts do
		parts[#parts + 1] = ".."
	end
	for i = common + 1, #targetParts do
		parts[#parts + 1] = targetParts[i]
	end
	return #parts > 0 and table.concat(parts, "/") or "."
end

local function is_absolute_path(path)
	path = (path or ""):gsub("\\", "/")
	return path:sub(1, 1) == "/" or path:match("^%a:/") ~= nil
end

local function current_directory()
	local command = package.config and package.config:sub(1, 1) == "\\" and "cd" or "pwd"
	local opened, handle = pcall(io.popen, command)
	if not opened or not handle then
		return nil
	end
	local directory = handle:read("*l")
	handle:close()
	if not directory or directory == "" then
		return nil
	end
	return normalize_path(directory)
end

local function leading_parent_count(path)
	local _, parts, absolute = path_info(path)
	if absolute then
		return 0
	end
	local count = 0
	for _, part in ipairs(parts) do
		if part ~= ".." then
			break
		end
		count = count + 1
	end
	return count
end

local function paths_equal(first, second)
	first = normalize_path(first)
	second = normalize_path(second)
	if is_absolute_path(first) ~= is_absolute_path(second) then
		local cwd = current_directory()
		if not cwd then
			error("Could not determine the current directory to compare file paths")
		end
		if not is_absolute_path(first) then
			first = normalize_path(cwd .. "/" .. first)
		end
		if not is_absolute_path(second) then
			second = normalize_path(cwd .. "/" .. second)
		end
	end
	if package.config and package.config:sub(1, 1) == "\\" then
		return first:lower() == second:lower()
	end
	return first == second
end

local function rebase_map_sources(map, mapPath)
	local mapDirectory = path_directory(mapPath)
	local cwd
	for i, source in ipairs(map.sources or {}) do
		if type(source) == "string"
			and not source:match("^[%a][%w+.-]*://")
			and not is_absolute_path(source)
		then
			local normalizedSource = normalize_path(source)
			local needsCwd = is_absolute_path(mapDirectory)
				or leading_parent_count(mapDirectory) ~= leading_parent_count(normalizedSource)
			if needsCwd then
				cwd = cwd or current_directory()
				if not cwd then
					error("Could not determine the current directory to rebase source paths")
				end
				local absoluteSource = normalize_path(cwd .. "/" .. normalizedSource)
				map.sources[i] = relative_path(mapDirectory, absoluteSource)
			else
				map.sources[i] = relative_path(mapDirectory, normalizedSource)
			end
		end
	end
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

local function run_trace()
	if arg[2] == "--help" or arg[2] == "-h" then
		print("Usage: prometheus-lua trace --map <file.map> <traceback.txt|->")
		print("Read a traceback from a file or standard input and rewrite generated locations.")
		return
	end

	local mapPath, tracebackPath
	local i = 2
	while i <= #arg do
		local current = arg[i]
		if current == "--map" then
			i = i + 1
			if not arg[i] then
				Prometheus.Logger:error('Option "--map" requires a path')
			end
			mapPath = arg[i]
		elseif current:sub(1, 1) == "-" and current ~= "-" then
			Prometheus.Logger:error(string.format('Unknown trace option "%s"', current))
		elseif tracebackPath then
			Prometheus.Logger:error(string.format('Unexpected argument "%s"', current))
		else
			tracebackPath = current
		end
		i = i + 1
	end

	if not mapPath then
		Prometheus.Logger:error('Trace requires "--map <file.map>"')
	end
	if not tracebackPath then
		Prometheus.Logger:error("Trace requires a traceback file or '-' for standard input")
	end
	local sourceMapApi = Prometheus.SourceMap
	if type(sourceMapApi) ~= "table" or type(sourceMapApi.decode) ~= "function" then
		Prometheus.Logger:error("Source map support is unavailable in this Prometheus build")
	end

	local mapJson = read_file(mapPath)
	if mapJson == nil then
		Prometheus.Logger:error(string.format('Could not read source map "%s"', mapPath))
	end
	local decoded, sourceMap = pcall(sourceMapApi.decode, mapJson)
	if not decoded then
		Prometheus.Logger:error(string.format('Invalid source map "%s": %s', mapPath, tostring(sourceMap)))
	end

	local traceback
	if tracebackPath == "-" then
		traceback = io.stdin:read("*a")
	else
		traceback = read_file(tracebackPath)
		if traceback == nil then
			Prometheus.Logger:error(string.format('Could not read traceback "%s"', tracebackPath))
		end
	end

	local Traceback = require("prometheus.traceback")
	local formattedOk, formatted = pcall(Traceback.format, traceback, sourceMap, mapPath, sourceMapApi)
	if not formattedOk then
		Prometheus.Logger:error(string.format("Could not format traceback: %s", tostring(formatted)))
	end
	io.stdout:write(formatted)
end

local function run_cli()
	if arg[1] == "trace" then
		run_trace()
		return
	end

	-- CLI
	local config, sourceFile, outFile, luaVersion, prettyPrint
	local sourceMapFile, omitSourceContent

	Prometheus.colors.enabled = true

	-- Parse Arguments
	local i = 1
	while i <= #arg do
		local curr = arg[i]
		if curr:sub(1, 2) == "--" then
			if curr == "--preset" or curr == "--p" then
				if config then
					Prometheus.Logger:warn("The config was set multiple times")
				end

				i = i + 1
				local preset = Prometheus.Presets[arg[i]]
				if not preset then
					Prometheus.Logger:error(string.format('A Preset with the name "%s" was not found!', tostring(arg[i])))
				end

				config = preset
			elseif curr == "--config" or curr == "--c" then
				i = i + 1
				local filename = tostring(arg[i])
				if not file_exists(filename) then
					Prometheus.Logger:error(string.format('The config file "%s" was not found!', filename))
				end

				local content = table.concat(lines_from(filename), "\n")
				-- Load Config from File
				local func, err = load_chunk(content, "@" .. filename, {})
				if not func then
					Prometheus.Logger:error(string.format('Failed to parse config file "%s": %s', filename, tostring(err)))
				end
				config = func()
			elseif curr == "--out" or curr == "--o" then
				i = i + 1
				if outFile then
					Prometheus.Logger:warn("The output file was specified multiple times!")
				end
				outFile = arg[i]
			elseif curr == "--source-map" then
				i = i + 1
				if not arg[i] or arg[i]:sub(1, 2) == "--" then
					Prometheus.Logger:error('Option "--source-map" requires a path')
				end
				sourceMapFile = arg[i]
			elseif curr == "--source-map-no-sources" then
				omitSourceContent = true
			elseif curr == "--nocolors" then
				Prometheus.colors.enabled = false
			elseif curr == "--Lua51" then
				luaVersion = "Lua51"
			elseif curr == "--LuaU" then
				luaVersion = "LuaU"
			elseif curr == "--pretty" then
				prettyPrint = true
			elseif curr == "--saveerrors" then
				-- Override error callback
				Prometheus.Logger.errorCallback = function(...)
					local args = { ... }
					local message = table.concat(args, " ")
					io.stderr:write(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")

					local fileName = sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt"
						or sourceFile .. ".error.txt"
					local handle = io.open(fileName, "w")
					handle:write(message)
					handle:close()

					os.exit(1)
				end
			else
				Prometheus.Logger:warn(string.format('The option "%s" is not valid and therefore ignored', curr))
			end
		else
			if sourceFile then
				Prometheus.Logger:error(string.format('Unexpected argument "%s"', arg[i]))
			end
			sourceFile = tostring(arg[i])
		end
		i = i + 1
	end

	if not sourceFile then
		Prometheus.Logger:error("No input file was specified!")
	end

	if not config then
		Prometheus.Logger:warn("No config was specified, falling back to Minify preset")
		config = Prometheus.Presets.Minify
	end

	-- Add Option to override Lua Version
	config.LuaVersion = luaVersion or config.LuaVersion
	config.PrettyPrint = prettyPrint ~= nil and prettyPrint or config.PrettyPrint
	if sourceMapFile then
		config.SourceMap = true
	end
	if omitSourceContent then
		config.SourceMapIncludeSources = false
	end

	if not file_exists(sourceFile) then
		Prometheus.Logger:error(string.format('The File "%s" was not found!', sourceFile))
	end

	if not outFile then
		if sourceFile:sub(-4) == ".lua" then
			outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua"
		else
			outFile = sourceFile .. ".obfuscated.lua"
		end
	end
	if not sourceMapFile and config.SourceMap == true then
		sourceMapFile = outFile .. ".map"
	end
	if sourceMapFile then
		local sameOk, sameOutput = pcall(paths_equal, sourceMapFile, outFile)
		if not sameOk then
			Prometheus.Logger:error(string.format("Could not validate source map path: %s", tostring(sameOutput)))
		end
		if sameOutput then
			Prometheus.Logger:error("The source map path must differ from the generated output path")
		end
		sameOk, sameOutput = pcall(paths_equal, sourceMapFile, sourceFile)
		if not sameOk then
			Prometheus.Logger:error(string.format("Could not validate source map path: %s", tostring(sameOutput)))
		end
		if sameOutput then
			Prometheus.Logger:error("The source map path must differ from the input source path")
		end
	end

	local source = read_file(sourceFile)
	if source == nil then
		Prometheus.Logger:error(string.format('Could not read input file "%s"', sourceFile))
	end
	local pipeline = Prometheus.Pipeline:fromConfig(config)
	local out, sourceMap = pipeline:apply(source, sourceFile)
	local sourceMapJson
	if sourceMapFile then
		if type(sourceMap) ~= "table" then
			Prometheus.Logger:error("The pipeline did not return a source map; check that source map support is enabled")
		end
		if type(Prometheus.SourceMap) ~= "table" or type(Prometheus.SourceMap.encode) ~= "function" then
			Prometheus.Logger:error("Source map support is unavailable in this Prometheus build")
		end
		sourceMap.file = path_basename(outFile)
		local rebasedOk, rebaseError = pcall(rebase_map_sources, sourceMap, sourceMapFile)
		if not rebasedOk then
			Prometheus.Logger:error(string.format("Could not rebase source paths: %s", tostring(rebaseError)))
		end
		local encoded, mapOrError = pcall(Prometheus.SourceMap.encode, sourceMap)
		if not encoded then
			Prometheus.Logger:error(string.format("Could not encode source map: %s", tostring(mapOrError)))
		end
		sourceMapJson = mapOrError
	end
	Prometheus.Logger:info(string.format('Writing output to "%s"', outFile))

	-- Write Output
	local wrote, writeError = write_file(outFile, out)
	if not wrote then
		Prometheus.Logger:error(string.format('Could not write output file "%s": %s', outFile, tostring(writeError)))
	end
	if sourceMapFile then
		wrote, writeError = write_file(sourceMapFile, sourceMapJson)
		if not wrote then
			Prometheus.Logger:error(string.format('Could not write source map "%s": %s', sourceMapFile, tostring(writeError)))
		end
	end
end

local ok, err = xpcall(run_cli, function(e)
	return tostring(e)
end)
if not ok then
	local message = tostring(err):gsub("^.-:%d+:%s*", "")
	io.stderr:write(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")
	os.exit(1)
end

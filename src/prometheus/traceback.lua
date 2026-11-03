-- Utilities for translating generated Lua traceback locations through a source map.

local Traceback = {}
local util = require('prometheus.util')

local function normalize_path(path)
	return (path or ""):gsub("\\", "/"):gsub("/+", "/")
end

local function basename(path)
	path = normalize_path(path)
	return path:match("([^/]+)$") or path
end

local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

local function map_file_matches(filename, mapFile)
	filename = trim(filename):gsub("^@", "")
	mapFile = trim(mapFile or "")
	if filename == "" or mapFile == "" then
		return false
	end

	local normalizedFilename = normalize_path(filename)
	local normalizedMapFile = normalize_path(mapFile)
	if normalizedFilename == normalizedMapFile or basename(normalizedFilename) == basename(normalizedMapFile) then
		return true
	end
	-- Lua shortens long chunk filenames to "..." followed by their tail.
	-- Require a substantial retained suffix to avoid guessing from short names.
	if normalizedFilename:sub(1, 3) == "..." then
		local suffix = normalizedFilename:sub(4)
		return #suffix >= 32 and normalizedMapFile:sub(-#suffix) == suffix
	end
	return false
end

local function source_match(candidate, mapFile)
	candidate = trim(candidate)
	local normalizedCandidate = normalize_path(candidate:gsub("^@", ""))
	local normalizedMapFile = normalize_path(trim(mapFile or ""))
	if normalizedCandidate == normalizedMapFile then
		return ""
	end

	-- Lua runtimes prefix the main chunk error with their executable name,
	-- such as "lua: " or "lua5.1: ". Only strip a runtime prefix when its
	-- remainder matches the generated filename, so colons in paths are safe.
	local prefix, rest = candidate:match("^([%a][%w_.-]*:%s+)(.*)$")
	if prefix and map_file_matches(rest, mapFile) then
		return prefix
	end
	if map_file_matches(candidate, mapFile) then
		return ""
	end
	return nil
end

local function find_lua_location(line, mapFile)
	local searchAt = 1
	local selected
	while true do
		local first, afterNumber, number = line:find(":(%d+):", searchAt)
		if not first then
			break
		end

		local candidate = line:sub(1, first - 1)
		local wrapper = source_match(candidate, mapFile)
		if wrapper then
			selected = {
				start = first,
				line = tonumber(number),
				wrapper = wrapper,
				indent = line:match("^(%s*)") or "",
			}
		end
		searchAt = afterNumber + 1
	end
	return selected
end

local function find_luau_location(line, mapFile)
	local indent, body = line:match("^(%s*)(.*)$")
	local prefix, filename, separator, number, suffix = body:match("^(Script%s+['\"])(.-)(['\"],%s*Line%s+)(%d+)(.*)$")
	if prefix and source_match(filename, mapFile) then
		return {
			indent = indent,
			luauPrefix = prefix,
			luauSeparator = separator,
			line = tonumber(number),
			luauSuffix = suffix,
		}
	end
	return nil
end

local function split_lines(value)
	local lines = {}
	local start = 1
	while true do
		local newline = value:find("\n", start, true)
		if not newline then
			if start <= #value then
				lines[#lines + 1] = value:sub(start):gsub("\r$", "")
			end
			break
		end
		lines[#lines + 1] = value:sub(start, newline - 1):gsub("\r$", "")
		start = newline + 1
		if start > #value then
			break
		end
	end
	return lines, value:sub(-1) == "\n"
end

local function map_directory(mapPath)
	local normalized = normalize_path(mapPath or "")
	return normalized:match("^(.*)/[^/]*$") or "."
end

local function is_absolute(path)
	path = normalize_path(path)
	return path:sub(1, 1) == "/" or path:match("^%a:/") ~= nil
end

local function resolve_source_path(source, sourceRoot, mapPath)
	local normalizedSource = normalize_path(source)
	if is_absolute(normalizedSource) then
		return normalizedSource
	end

	local root = normalize_path(sourceRoot or "")
	if root ~= "" and not is_absolute(root) then
		root = map_directory(mapPath) .. "/" .. root
	elseif root == "" then
		root = map_directory(mapPath)
	end
	return normalize_path(root .. "/" .. normalizedSource)
end

local function read_source(source, sourceRoot, mapPath)
	local path = resolve_source_path(source, sourceRoot, mapPath)
	local file = io.open(path, "rb")
	if not file then
		return nil, path
	end
	local content = file:read("*a")
	file:close()
	return content, path
end

local function excerpt_lines(content)
	local lines = {}
	local start = 1
	while true do
		local newline = content:find('[\r\n]', start)
		if not newline then
			lines[#lines + 1] = content:sub(start)
			break
		end
		lines[#lines + 1] = content:sub(start, newline - 1)
		local paired = util.isNewlinePair(content:sub(newline, newline), content:sub(newline + 1, newline + 1))
		start = newline + (paired and 2 or 1)
	end
	return lines
end

local function source_map_api(explicitApi)
	if explicitApi and type(explicitApi.lookup) == "function" then
		return explicitApi
	end

	-- Keeping the explicit API parameter optional makes this module convenient
	-- to use directly while the CLI passes the public Prometheus.SourceMap API.
	local ok, api = pcall(require, "prometheus.sourcemap")
	if ok and type(api) == "table" and type(api.lookup) == "function" then
		return api
	end
	return nil
end

local function rewrite_lines(lines, map, mapApi)
	local rewritten = {}
	local locations = {}
	for _, line in ipairs(lines) do
		local luau = find_luau_location(line, map.file)
		if luau then
			local location = mapApi.lookup(map, luau.line)
			if location then
				local indent = luau.indent
				line = indent .. luau.luauPrefix .. location.source .. luau.luauSeparator
					.. tostring(location.line) .. luau.luauSuffix
					locations[#locations + 1] = location
			end
		else
			local location = find_lua_location(line, map.file)
			if location then
				local mapped = mapApi.lookup(map, location.line)
				if mapped then
					local before = line:sub(1, location.start - 1)
					local prefix = before:match("^(%s*)") or ""
					line = prefix .. location.wrapper .. mapped.source .. ":" .. tostring(mapped.line)
						.. line:sub(location.start + #tostring(location.line) + 1)
					locations[#locations + 1] = mapped
				end
			end
		end
		rewritten[#rewritten + 1] = line
	end
	return rewritten, locations
end

local function append_excerpts(lines, locations, map, mapPath)
	if #locations == 0 then
		return lines
	end

	local excerptBlocks = {}
	local seen = {}
	for _, location in ipairs(locations) do
		local key = tostring(location.source) .. ":" .. tostring(location.line)
		if not seen[key] then
			seen[key] = true
			local content = location.content
			local sourcePath
			if content == nil then
				content, sourcePath = read_source(location.source, map.sourceRoot, mapPath)
			end

			local block = { string.format("  %s:%d", location.source, location.line) }
			if content == nil then
				block[#block + 1] = "    (source excerpt unavailable: could not read " .. tostring(sourcePath) .. ")"
			else
				local sourceLines = excerpt_lines(content)
				local first = math.max(1, location.line - 2)
				local last = math.min(#sourceLines, location.line + 2)
				for lineNumber = first, last do
					local marker = lineNumber == location.line and ">" or " "
					block[#block + 1] = string.format("    %s %d | %s", marker, lineNumber, sourceLines[lineNumber])
				end
				if #sourceLines == 0 then
					block[#block + 1] = "    (source excerpt unavailable: source is empty)"
				end
			end
			excerptBlocks[#excerptBlocks + 1] = table.concat(block, "\n")
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "Source excerpts:"
	for _, block in ipairs(excerptBlocks) do
		lines[#lines + 1] = block
	end
	return lines
end

function Traceback.format(traceback, map, mapPath, explicitMapApi)
	assert(type(traceback) == "string", "traceback must be a string")
	assert(type(map) == "table", "source map must be a table")
	local mapApi = source_map_api(explicitMapApi)
	assert(mapApi, "source map lookup API is unavailable")
	local lines, hadTrailingNewline = split_lines(traceback)
	local rewritten, locations = rewrite_lines(lines, map, mapApi)
	append_excerpts(rewritten, locations, map, mapPath)
	local result = table.concat(rewritten, "\n")
	if hadTrailingNewline then
		result = result .. "\n"
	end
	return result
end

return Traceback

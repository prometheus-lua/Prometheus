local M = {}

function M.quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function M.read(path)
    local f = assert(io.open(path, "rb"))
    local contents = f:read("*a")
    f:close()
    return contents
end

function M.write(path, contents)
    local f = assert(io.open(path, "wb"))
    assert(f:write(contents))
    assert(f:close())
end

-- Lua 5.1 returns the encoded wait status; later Lua versions return a tuple.
-- Do not use io.popen():close(): stock Lua 5.1 loses child exit status there.
function M.status(a, why, code)
    if type(a) == "number" then
        if a == -1 then return 125 end
        local signal = a % 128
        if signal ~= 0 then return 128 + signal end
        return math.floor(a / 256)
    end
    if a == true then return 0 end
    return why == "signal" and 128 + (code or 0) or (code or 125)
end

function M.run(command, cwd, seconds, log)
    local shell = "cd " .. M.quote(cwd) .. " && LC_ALL=C TZ=UTC timeout --kill-after=5s " ..
        M.quote(seconds) .. "s " .. command
    local status = M.status(os.execute("(" .. shell .. ") > " .. M.quote(log) .. " 2>&1"))
    return M.read(log), status
end

function M.mkdir(path)
    assert(M.status(os.execute("mkdir -p " .. M.quote(path))) == 0, "cannot create " .. path)
end

function M.tempdir(parent, prefix)
    local p = assert(io.popen("mktemp -d " .. M.quote(parent .. "/" .. prefix .. "-XXXXXX")))
    local path = assert(p:read("*l"))
    p:close()
    assert(path ~= "", "cannot create temporary directory")
    return path
end

function M.files(dir)
    local p = assert(io.popen("find " .. M.quote(dir) .. " -maxdepth 1 -type f -name '*.lua' -printf '%f\\n'"))
    local files = {}
    for file in p:lines() do files[#files + 1] = file end
    p:close()
    table.sort(files)
    return files
end

function M.normalize(s)
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
    while lines[#lines] == "" do table.remove(lines) end
    return table.concat(lines, "\n")
end

return M

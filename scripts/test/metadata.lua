-- Directives are only read from the leading whitespace/comment region.
local M = {}

function M.parse(code, filename)
    local meta = { runtimes = {}, skip_presets = {}, skip = false }
    filename = filename or "<test>"
    local function directive(line, line_number)
        line = line:gsub("^%s*%-%-%s*", "")
        local body = line:match("^%s*@(.*)$")
        if not body then return end
        local key, value = body:match("^([%w_%-]+)%s*(.-)%s*$")
        local function invalid(message)
            error(filename .. ":" .. line_number .. ": " .. message, 0)
        end
        if not key then invalid("malformed metadata directive") end
        key = key:gsub("_", "-")
        if key == "skip" or key == "luau-only" then
            if value ~= "" then invalid("@" .. key .. " takes no arguments") end
            if key == "skip" then meta.skip = true else meta.runtimes.luau = true end
        elseif key == "runtime" or key == "skip-preset" then
            if value == "" then invalid("@" .. key .. " requires an argument") end
            for token in value:gmatch("%S+") do
                if key == "runtime" then
                    token = token:lower()
                    if token == "lua51" then token = "lua5.1" end
                    if token ~= "lua5.1" and token ~= "luau" and token ~= "luajit" then
                        invalid("unknown runtime " .. token)
                    end
                    meta.runtimes[token] = true
                else
                    meta.skip_presets[token] = true
                end
            end
        else
            invalid("unknown metadata directive @" .. key)
        end
    end

    local pos, line_number = 1, 1
    local function consume(last, inspect)
        local chunk = code:sub(pos, last)
        if inspect then
            local n = line_number
            for line in (chunk .. "\n"):gmatch("(.-)\n") do
                directive(line:gsub("\r$", ""), n)
                n = n + 1
            end
        end
        local _, newlines = chunk:gsub("\n", "")
        line_number = line_number + newlines
        pos = last + 1
    end
    if code:sub(1, 1) == "#" then consume((code:find("\n", 1, true) or (#code + 1)) - 1) end
    while pos <= #code do
        local whitespace = code:sub(pos):match("^%s+")
        if whitespace then
            consume(pos + #whitespace - 1)
        elseif code:sub(pos, pos + 1) == "--" then
            local opener, equals = code:sub(pos + 2):match("^(%[(=*)%[)")
            if opener then
                consume(pos + 1 + #opener)
                local close = "]" .. equals .. "]"
                local last = code:find(close, pos, true)
                if not last then error(filename .. ":" .. line_number .. ": unterminated header comment", 0) end
                consume(last - 1, true)
                consume(last + #close - 1)
            else
                consume((code:find("\n", pos, true) or (#code + 1)) - 1, true)
            end
        else
            break
        end
    end
    return meta
end

return M

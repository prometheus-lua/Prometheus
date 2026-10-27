-- Call, return, and register clearing handlers. Fixed arities keep argument
-- passing in native Lua calls so the VM does not build a temporary arg pack.
local M = {}

local bodies = {
    CALL = [==[
        x, y = R[b], R[c]
        if nativeGetfenv and x == nativeGetfenv and (y.n == 0 or y[1] == nil or y[1] == 1) then
            if d == -1 then
                R[a] = { n = 1, Env }
            elseif d == 1 then
                R[a] = Env
            end
        elseif d == -1 then
            R[a] = pack(x(nativeUnpack(y, 1, y.n)))
        elseif d == 1 then
            R[a] = x(nativeUnpack(y, 1, y.n))
        else
            x(nativeUnpack(y, 1, y.n))
        end
    ]==],
    TAILCALL = [==[
        x, y = R[a], R[b]
        if nativeGetfenv and x == nativeGetfenv and (y.n == 0 or y[1] == nil or y[1] == 1) then
            return Env
        end
        return x(nativeUnpack(y, 1, y.n))
    ]==],
    CLEARS = [==[
        for x = 1, #a do
            R[a[x]] = nil
        end
    ]==],
    RETURN0 = [==[return]==],
    RETURN1 = [==[return R[a]]==],
    RETURN2 = [==[return R[a], R[b]]==],
    RETURN3 = [==[return R[a], R[b], R[c]]==],
}

local function callBody(arity)
    local args = {}
    for i = 1, arity do
        args[i] = "R[c[" .. tostring(i) .. "]]"
    end
    local invocation = "x(" .. table.concat(args, ", ") .. ")"
    local intercept = arity == 0
        and "nativeGetfenv and x == nativeGetfenv"
        or "nativeGetfenv and x == nativeGetfenv and (R[c[1]] == nil or R[c[1]] == 1)"
    return "x = R[b]\n"
        .. "if " .. intercept .. " then\n"
        .. "    if d == -1 then\n"
        .. "        R[a] = { n = 1, Env }\n"
        .. "    elseif d == 1 then\n"
        .. "        R[a] = Env\n"
        .. "    end\n"
        .. "elseif d == -1 then\n"
        .. "    R[a] = pack(" .. invocation .. ")\n"
        .. "elseif d == 1 then\n"
        .. "    R[a] = " .. invocation .. "\n"
        .. "else\n"
        .. "    " .. invocation .. "\n"
        .. "end"
end

local function tailCallBody(arity)
    local args = {}
    for i = 1, arity do
        args[i] = "R[b[" .. tostring(i) .. "]]"
    end
    local invocation = "x(" .. table.concat(args, ", ") .. ")"
    local intercept = arity == 0
        and "nativeGetfenv and x == nativeGetfenv"
        or "nativeGetfenv and x == nativeGetfenv and (R[b[1]] == nil or R[b[1]] == 1)"
    return "x = R[a]\n"
        .. "if " .. intercept .. " then\n"
        .. "    return Env\n"
        .. "end\n"
        .. "return " .. invocation
end

for arity = 0, 3 do
    bodies["CALL" .. tostring(arity)] = callBody(arity)
    bodies["TAILCALL" .. tostring(arity)] = tailCallBody(arity)
end

function M.merge(target)
    for name, body in pairs(bodies) do
        target[name] = body
    end
    return target
end

return M

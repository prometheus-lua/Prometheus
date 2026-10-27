-- Opcode bodies are kept separate from runtime.lua so both files stay small.
local M = {}
local callBodies = require("prometheus.vm.runtime_calls")

local bodies = {
    LOAD = [==[R[a] = K[b]]==],
    NIL = [==[R[a] = nil]==],
    MOVE = [==[R[a] = R[b]]==],
    CLEAR = [==[R[a] = nil]==],
    CELL = [==[x = R[b]; R[a] = { x }]==],
    GETCELL = [==[R[a] = R[b][1]]==],
    SETCELL = [==[R[a][1] = R[b]]==],
    GETUP = [==[R[a] = U[b][1]]==],
    SETUP = [==[U[a][1] = R[b]]==],
    GLOBAL = [==[R[a] = Env[K[b]]]==],
    SETGLOBAL = [==[Env[K[a]] = R[b]]==],
    GETTABLE = [==[R[a] = R[b][R[c]]]==],
    SETTABLE = [==[R[a][R[b]] = R[c]]==],
    TABLE = [==[R[a] = {}]==],
    EXPAND = [==[
        x = R[c]
        for y = 1, x.n do
            R[a][b + y - 1] = x[y]
        end
    ]==],
    ARGS = [==[
        x = { n = 0 }
        for _, y in nativeIpairs(b) do
            x.n = x.n + 1
            x[x.n] = R[y]
        end
        if c ~= 0 then
            y = R[c]
            for d = 1, y.n do
                x.n = x.n + 1
                x[x.n] = y[d]
            end
        end
        R[a] = x
    ]==],
    TAKE = [==[R[a] = R[b][c]]==],
    VARARG = [==[R[a] = V]==],
    RETURN = [==[
        x = R[a]
        return nativeUnpack(x, 1, x.n)
    ]==],
    CLOSURE = [==[
        x = P.children[b]
        y = {}
        for d = 1, #x.captures do
            local capture = x.captures[d]
            if capture[1] == 0 then
                y[d] = R[capture[2]]
            else
                y[d] = U[capture[2]]
            end
        end
        R[a] = make(x, y, Env)
    ]==],
    JMP = [==[pc = a]==],
    JFALSE = [==[x = R[a]; R[a] = nil; if not x then pc = b end]==],
    JTRUE = [==[x = R[a]; R[a] = nil; if x then pc = b end]==],
    ADD = [==[R[a] = R[b] + R[c]]==],
    SUB = [==[R[a] = R[b] - R[c]]==],
    MUL = [==[R[a] = R[b] * R[c]]==],
    DIV = [==[R[a] = R[b] / R[c]]==],
    MOD = [==[R[a] = R[b] % R[c]]==],
    POW = [==[R[a] = R[b] ^ R[c]]==],
    CONCAT = [==[R[a] = R[b] .. R[c]]==],
    LT = [==[R[a] = R[b] < R[c]]==],
    LE = [==[R[a] = R[b] <= R[c]]==],
    GT = [==[R[a] = R[b] > R[c]]==],
    GE = [==[R[a] = R[b] >= R[c]]==],
    EQ = [==[R[a] = R[b] == R[c]]==],
    NE = [==[R[a] = R[b] ~= R[c]]==],
    NOT = [==[R[a] = not R[b]]==],
    NEG = [==[R[a] = -R[b]]==],
    LEN = [==[R[a] = #R[b]]==],
    FORPREP = [==[
        x = nativeTonumber(R[a])
        if x == nil then nativeError("'for' initial value must be a number", 0) end
        R[a] = x
        x = nativeTonumber(R[b])
        if x == nil then nativeError("'for' limit must be a number", 0) end
        R[b] = x
        x = nativeTonumber(R[c])
        if x == nil then nativeError("'for' step must be a number", 0) end
        R[c] = x
    ]==],
    FORCHECK = [==[
        if R[d] ~= R[d] then
            R[a] = false
        elseif R[d] > 0 then
            R[a] = R[b] <= R[c]
        else
            R[a] = R[b] >= R[c]
        end
    ]==],
}

callBodies.merge(bodies)

function M.build(opcodes)
    local entries = {}
    for name, id in pairs(opcodes) do
        local body = bodies[name]
        assert(body and type(id) == "number", "Missing VM handler for opcode " .. tostring(name))
        entries[#entries + 1] = { id = id, name = name, body = body }
    end
    table.sort(entries, function(left, right) return left.id < right.id end)
    for i = 2, #entries do
        assert(entries[i - 1].id < entries[i].id, "Duplicate VM opcode ID")
    end

    local function indent(source, prefix)
        return prefix .. source:gsub("\n", "\n" .. prefix)
    end

    local function emit(first, last, depth)
        local prefix = string.rep("    ", depth)
        if first == last then
            local entry = entries[first]
            return prefix .. "if opcode == " .. tostring(entry.id) .. " then\n"
                .. indent(entry.body, prefix .. "    ") .. "\n"
                .. prefix .. "else\n"
                .. prefix .. "    nativeError('unknown VM opcode: ' .. tostring(opcode), 0)\n"
                .. prefix .. "end"
        end

        local middle = math.floor((first + last) / 2)
        local split = entries[middle].id
        return prefix .. "if opcode <= " .. tostring(split) .. " then\n"
            .. emit(first, middle, depth + 1) .. "\n"
            .. prefix .. "else\n"
            .. emit(middle + 1, last, depth + 1) .. "\n"
            .. prefix .. "end"
    end

    assert(#entries > 0, "No VM opcodes registered")
    return emit(1, #entries, 0)
end

return M

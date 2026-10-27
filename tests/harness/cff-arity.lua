local Prometheus = require("src.prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local function pack(...) return {n = select("#", ...), ...} end
-- The outer wrapper must preserve chunk arguments and chunk return counts too.
for _, seed in ipairs({1, 2, 3}) do
    local config = {LuaVersion = "Lua51", Seed = seed, Steps = {{Name = "Cff"}}}
    local generated = Prometheus.Pipeline:fromConfig(config):apply("return ...")
    local chunk = assert(loadstring(generated))
    for _, args in ipairs({pack(), pack(nil), pack(1, nil), pack(nil, 2, nil)}) do
        local actual = pack(chunk(unpack(args, 1, args.n)))
        assert(actual.n == args.n, "changed chunk arity")
        for i = 1, args.n do assert(actual[i] == args[i], "changed chunk value") end
    end
    local collapsed = assert(loadstring(Prometheus.Pipeline:fromConfig(config):apply("return (...)")))
    for _, args in ipairs({pack(), pack(nil), pack(1, nil), pack(nil, 2, nil)}) do
        local actual = pack(collapsed(unpack(args, 1, args.n)))
        assert(actual.n == 1 and actual[1] == args[1], "parenthesized chunk varargs must return one value")
    end
    local generated = Prometheus.Pipeline:fromConfig(config):apply("return nil, nil")
    local actual = pack(assert(loadstring(generated))())
    assert(actual.n == 2 and actual[1] == nil and actual[2] == nil)

    -- Cleanup must preserve values and remain valid when registers spill.
    local entries = {}
    for i = 1, 250 do entries[i] = "value(" .. i .. ")" end
    local source = "local function value(i) return i end; local values = {" .. table.concat(entries, ",") .. "}; assert(#values == 250 and values[250] == 250); return values, nil"
    local actual = pack(assert(loadstring(Prometheus.Pipeline:fromConfig(config):apply(source)))())
    assert(actual.n == 2 and actual[1][1] == 1 and actual[1][250] == 250 and actual[2] == nil)

    -- Literal initializers may merge, but must stay within Lua's assignment limit.
    for i = 1, 250 do entries[i] = tostring(i) end
    local source = "local values = {" .. table.concat(entries, ",") .. "}; for i = 1, 250 do assert(values[i] == i) end; return values, nil"
    local actual = pack(assert(loadstring(Prometheus.Pipeline:fromConfig(config):apply(source)))())
    assert(actual.n == 2 and #actual[1] == 250 and actual[2] == nil)
end
print("CFF chunk arity regression checks passed")

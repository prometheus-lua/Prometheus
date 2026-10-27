local Prometheus = require("src.prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local function pack(...) return {n = select("#", ...), ...} end
-- The outer wrapper must preserve chunk arguments and chunk return counts too.
for _, seed in ipairs({1, 2, 3}) do
    local config = {LuaVersion = "Lua51", Seed = seed, Steps = {{Name = "Vmify"}}}
    local generated = Prometheus.Pipeline:fromConfig(config):apply("return ...")
    local chunk = assert(loadstring(generated))
    for _, args in ipairs({pack(), pack(nil), pack(1, nil), pack(nil, 2, nil)}) do
        local actual = pack(chunk(unpack(args, 1, args.n)))
        assert(actual.n == args.n, "changed chunk arity")
        for i = 1, args.n do assert(actual[i] == args[i], "changed chunk value") end
    end
    local generated = Prometheus.Pipeline:fromConfig(config):apply("return nil, nil")
    local actual = pack(assert(loadstring(generated))())
    assert(actual.n == 2 and actual[1] == nil and actual[2] == nil)
end
print("VM chunk arity regression checks passed")

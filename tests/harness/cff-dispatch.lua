local Prometheus = require("src.prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Compiler = require("prometheus.cff.compiler")
local createBlock = Compiler.createBlock
local firstId

-- Force consecutive IDs so a rounded midpoint cannot silently skip a block.
function Compiler:createBlock()
    local block = createBlock(self)
    self.dispatchTestNextId = (self.dispatchTestNextId or (firstId - 1)) + 1
    block.id = self.dispatchTestNextId
    self.usedBlockIds[block.id] = true
    return block
end

local ok, err = pcall(function()
    -- Low IDs must not overwrite entries in the ordered block list.
    for _, start in ipairs({0, 100}) do
        firstId = start
        for seed = 1, 10 do
            local config = {LuaVersion = "Lua51", Seed = seed, Steps = {{Name = "Cff"}}}
            local pipeline = Prometheus.Pipeline:fromConfig(config)

            -- Four blocks exercise the short elseif dispatcher.
            local source = "local value=0; if ... then value=1 else value=2 end; return value"
            local chunk = assert(loadstring(pipeline:apply(source)))
            assert(chunk(true) == 1 and chunk(false) == 2, "short dispatcher selected the wrong block")

            -- More blocks exercise binary splits and their reversed comparisons.
            local source = "local value=...; if value<0 then return -1 elseif value==0 then return 0 elseif value<5 then return value*2 elseif value<10 then return value+20 else return value-10 end"
            local chunk = assert(loadstring(pipeline:apply(source)))
            for _, case in ipairs({{-2, -1}, {0, 0}, {1, 2}, {4, 8}, {5, 25}, {9, 29}, {10, 0}, {12, 2}}) do
                local actual = chunk(case[1])
                assert(actual == case[2], "binary dispatcher selected the wrong block: seed " .. seed ..
                    ", first ID " .. firstId .. ", input " .. case[1] .. ", got " .. tostring(actual))
            end
        end
    end
end)
Compiler.createBlock = createBlock
assert(ok, err)
print("CFF dispatch boundary regression checks passed")

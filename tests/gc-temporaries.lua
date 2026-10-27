-- @runtime lua5.1
-- Dead VM slots must not keep weakly referenced objects alive.
local weak = setmetatable({}, {__mode = "v"})
local object = {}
weak[1] = object
object = nil
collectgarbage()
assert(weak[1] == nil)

local function checkCollected()
    collectgarbage()
    assert(weak[1] == nil)
    return 7
end
local proxy = setmetatable({}, {
    __index = checkCollected,
    __newindex = checkCollected,
    __add = checkCollected,
    __unm = checkCollected,
    __concat = checkCollected,
})
do local discarded = {}; weak[1] = discarded; discarded = nil; assert(proxy.missing == 7) end
do local discarded = {}; weak[1] = discarded; discarded = nil; proxy.missing = true end
do local discarded = {}; weak[1] = discarded; discarded = nil; assert(proxy + proxy == 7) end
do local discarded = {}; weak[1] = discarded; discarded = nil; assert(-proxy == 7) end
do local discarded = {}; weak[1] = discarded; discarded = nil; assert(proxy .. proxy == 7) end

-- Trigger automatic collection through allocation inside a metamethod. The
-- caller's dead temporaries stay on its stack throughout the metamethod.
local automatic = setmetatable({}, {__index = function()
    -- Do not read the weak value during allocation: even the reference VM can
    -- keep that read's temporary alive until the next loop iteration.
    for i = 1, 100000 do local garbage = {i} end
    assert(weak[1] == nil)
    return true
end})
local pause = collectgarbage("setpause", 100)
local multiplier = collectgarbage("setstepmul", 1000)
collectgarbage("restart")
do local discarded = {}; weak[1] = discarded; discarded = nil; assert(automatic.missing) end
collectgarbage("setpause", pause)
collectgarbage("setstepmul", multiplier)

-- Live arguments, returned values, and loop state must survive cleanup.
local function returnLive(value)
    collectgarbage()
    assert(weak[1] == value)
    return value, nil
end
local live = {}
weak[1] = live
local result, other = returnLive(live)
assert(result == live and other == nil)
local total = 0
for i = 1, 5 do collectgarbage(); total = total + i end
assert(total == 15)
for _, value in ipairs({live}) do collectgarbage(); assert(value == live) end
local getLive = function() return live end
collectgarbage()
assert(getLive() == live)
print("GC temporaries OK")

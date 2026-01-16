-- Simple deterministic finite-state machine demonstration
local transitions = {
    idle = { start = "running" },
    running = { pause = "paused", stop = "stopped" },
    paused = { resume = "running", stop = "stopped" }
}

local steps = {
    { event = "start", expect = "running" },
    { event = "pause", expect = "paused" },
    { event = "resume", expect = "running" },
    { event = "stop", expect = "stopped" }
}

local state = "idle"
for idx, step in ipairs(steps) do
    local rule = transitions[state]
    state = rule and rule[step.event]
    assert(state == step.expect, string.format("bad transition at %d", idx))
    print(string.format("%d:%s->%s", idx, step.event, state))
end

print("final:" .. state)

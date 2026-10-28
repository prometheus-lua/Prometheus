local events = ''
local object = setmetatable({}, {
    __tostring = function()
        events ..= 't'
        return 'object'
    end,
})
local function first()
    events ..= 'a'
    return object, 'ignored'
end
local function second()
    events ..= 'b'
    return nil, 'ignored'
end
local function nothing() end
local function fromVarargs(...)
    return `vararg={...}`
end
local string = {format = function() return 'wrong format' end}
local tostring = function() return 'wrong tostring' end
local combined = `[{first()}] [{second()}] [{nothing()}]`
local nested = `outer {`inner {({x = {9}}).x[1]}`} and {'}'} and {if true then 'yes' elseif false then 'bad' else 'no'}`
local multiline = `multi {(
    function() return {answer = 42} end
)().answer}`
local escaped = `literal \{x} \` \\ \x41 \065 \u{42} 100%`
local withoutExpressions = `plain %%`
local formatPercent = `%% and %s: {42}%`
local upper = (`hello {1}`):upper()
local nul = `A\000{4}B`
local surrogate = `\u{D800}`
local empty = ``
local trimmed = `trim\z
    med`
local newline = `line\
end`
local env = getfenv()
env['prometheus_luau_iterator_1'] = 'global value'
local collision = `{prometheus_luau_iterator_1}`
env['prometheus_luau_iterator_1'] = nil
local embeddedLoop = `{(function()
    local total = 0
    for _, value in {2, 3} do total += value end
    return total
end)()}`
local savedString, savedTostring = env.string, env.tostring
env.string = {format = function() return 'changed global' end}
env.tostring = function() return 'changed tostring' end
local hiddenGlobals = `{true}|{nil}|{5.5}`
env.string, env.tostring = savedString, savedTostring
print(combined, events)
print(nested, multiline)
print(escaped, withoutExpressions, formatPercent, #nul, nul:byte(2), empty == '', trimmed, #newline)
print(hiddenGlobals, fromVarargs(1, 2), collision, embeddedLoop, upper, #surrogate, surrogate:byte(1, 3))

local Prometheus = require('src.prometheus')
local Parser = require('prometheus.parser')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

local function fails(source, version)
    local ok = pcall(function() Parser:new({LuaVersion = version}):parse(source) end)
    assert(not ok, 'expected invalid ' .. version .. ' source to fail: ' .. source)
end
fails('local x: number = 1', 'Lua51')
fails('local x = if true then 1 else 2', 'Lua51')
fails('type T =', 'LuaU')
fails('local x: |& usudhd  subd = 100', 'LuaU')
fails('local x: number | string & boolean = nil', 'LuaU')
fails('type T = typeof({value = })', 'LuaU')
fails('type T<P... = number> = {}', 'LuaU')
fails('local function f<T = number>() end', 'LuaU')
fails('local x: (number, string) = nil', 'LuaU')
fails('local x: {a: number = 1', 'LuaU')
fails('local f = function(x: ) end', 'LuaU')
fails('const x = 1', 'Lua51')
fails('local x = `text {1}`', 'Lua51')
fails('const value', 'LuaU')
fails('const x, y = 1', 'LuaU')
fails('local function f() return 1, 2 end; const x, y = (f())', 'LuaU')
fails('const x = 1; x = 2', 'LuaU')
fails('const x = 1; x += 2', 'LuaU')
fails('const x = 1; local y; y, x = 2, 3', 'LuaU')
fails('const x = 1; local function f() x = 2 end', 'LuaU')
fails('const function f() end; function f() end', 'LuaU')
fails('local x = `unclosed', 'LuaU')
fails('local x = `{}`', 'LuaU')
fails('`value {1}`', 'LuaU')
fails('local x = `{{1}}`', 'LuaU')
fails('local x = `value {1`', 'LuaU')
fails('local x = `\\u{110000}`', 'LuaU')

local emptyOk, emptyError = pcall(function()
    Parser:new({LuaVersion = 'LuaU'}):parse('local x = `empty {}`')
end)
assert(not emptyOk and tostring(emptyError):find('Position 1:', 1, true),
    'empty interpolation errors must refer to the original source')

local ok, message = pcall(function()
    Parser:new({LuaVersion = 'LuaU', LowerLuauIteration = true}):parse(
        'for i in {} do end\nlocal x: = 1')
end)
assert(not ok and tostring(message):find('Position 2:', 1, true),
    'iterator helper must not shift source error lines')

local reusable = Parser:new({LuaVersion = 'LuaU'})
assert(not pcall(function() reusable:parse('local x: |& Broken = 1') end))
assert(reusable:parse('local x: number = 1').body.statements[1])

for _, version in ipairs({'Lua51', 'LuaU'}) do
    for _, source in ipairs({
        'local function f() return ... end',
        'function object:f() print(...) end',
        'local function outer(...) return function() return ... end end',
        'local function f() do local args = {...} end end',
    }) do fails(source, version) end
    local parser = Parser:new({LuaVersion = version})
    assert(not pcall(function() parser:parse('local f = function() return ... end') end))
    assert(parser:parse('local function f() return 1 end; return ...'))
    assert(parser:parse('local function f(...) return function(...) return ... end end'))
end
local validCall, varargError = pcall(function()
    reusable:parse('local function f()\n print(...)\nend')
end)
assert(not validCall and tostring(varargError):find("Cannot use '...'", 1, true)
    and tostring(varargError):find('Position 2:', 1, true),
    'invalid varargs inside calls must retain their original diagnostic')

local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1})
assert(pipeline:getLuaVersion() == 'Lua51')
pipeline:setLuaVersion('LuaU')
assert(pipeline:getLuaVersion() == 'LuaU')
local result = assert(loadstring(pipeline:apply('local x: number = 3; return x')))()
assert(result == 3)
local whitespace = 'local x = `a\\z' .. string.char(11, 12) .. ' b`; return x'
assert(assert(loadstring(pipeline:apply(whitespace)))() == 'ab')
print('Luau parser and version selection checks passed')

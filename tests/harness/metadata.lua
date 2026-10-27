local parse = require("scripts.test.metadata").parse
local function test(header, expected)
    local actual = parse(header, "fixture.lua")
    assert(actual.skip == (expected.skip or false))
    for _, field in ipairs({"runtimes", "skip_presets"}) do
        for key in pairs(actual[field]) do assert((expected[field] or {})[key], field .. ": unexpected " .. key) end
        for key in pairs(expected[field] or {}) do assert(actual[field][key], field .. ": missing " .. key) end
    end
end
test("-- @skip\nerror('unused')", {skip = true})
test("#!/usr/bin/lua\n\n-- License\n-- @runtime LUA51 luau\n\n-- @skip-preset Weak Strong\nprint(1)",
    {runtimes = {["lua5.1"] = true, luau = true}, skip_presets = {Weak = true, Strong = true}})
test("--[=[\nlicense\n@runtime lua5.1\n-- @skip_preset Minify\n]=] -- @skip-preset Medium\nprint(1)",
    {runtimes = {["lua5.1"] = true}, skip_presets = {Minify = true, Medium = true}})
test("--[[ @luau_only ]]\n-- @skip_preset weak\n", {runtimes = {luau = true}, skip_presets = {weak = true}})
test("-- @luau-only\r\n", {runtimes = {luau = true}})
test("-- @runtime luajit", {runtimes = {luajit = true}})
test("-- Ordinary comment\nprint('-- @skip')\n-- @skip", {})
test("--[[ license ]] print(1) -- @skip", {})
test("print(1)\n-- @unknown", {})
for _, directive in ipairs({"@unknown", "@runtime", "@runtime lua54", "@skip-preset", "@skip extra", "@luau-only extra", "@"}) do
    local ok, err = pcall(parse, "-- " .. directive .. "\n", "bad.lua")
    assert(not ok and err:find("bad.lua:1:", 1, true), "expected diagnostic for " .. directive)
end
local ok = pcall(parse, "--[[ unterminated", "bad.lua")
assert(not ok)
print("Metadata regression checks passed")

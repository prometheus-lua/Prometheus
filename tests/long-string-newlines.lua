-- @runtime lua51
-- Raw CR bytes below are intentional: Lua omits the initial CR and normalizes internal CR to LF.
local value = [=[helloworld]=]
assert(value == "hello\nworld")
print("long string newline OK")

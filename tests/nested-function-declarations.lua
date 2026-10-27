-- Intermediate table lookups must depend on the table they read.
local t = {a = {b = {}}}
function t.a.f() return 42 end
function t.a.b.g() return 43 end
function t.a.b:method(value) return self.g() + value end
assert(t.a.f() == 42)
assert(t.a.b.g() == 43)
assert(t.a.b:method(7) == 50)

-- Lookups with observable side effects must finish before the method is stored.
local order = {}
local leaf = setmetatable({}, {
    __newindex = function(target, key, value)
        order[#order + 1] = "store " .. key
        rawset(target, key, value)
    end,
})
local middle = setmetatable({}, {
    __index = function(_, key)
        order[#order + 1] = "lookup " .. key
        return leaf
    end,
})
local proxy = setmetatable({}, {
    __index = function(_, key)
        order[#order + 1] = "lookup " .. key
        return middle
    end,
})
function proxy.a.b.f() return "done" end
assert(#order == 3 and order[1] == "lookup a" and order[2] == "lookup b" and order[3] == "store f")
assert(leaf.f() == "done")

-- Include a global root and a root captured by a nested closure.
nestedDeclarationRoot = {a = {b = {}}}
function nestedDeclarationRoot.a.b.f() return 44 end
assert(nestedDeclarationRoot.a.b.f() == 44)
nestedDeclarationRoot = nil
local function define()
    function t.a.b.captured() return t.a.f() end
end
define()
assert(t.a.b.captured() == 42)
print("nested function declarations OK")

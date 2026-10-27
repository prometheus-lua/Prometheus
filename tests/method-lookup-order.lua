-- Method lookups must observe prior declarations and table mutations.
local t = {}
function t:one() return 42 end
assert(t:one() == 42)
function t:two() return 43, nil end
local a, b = t:two()
assert(a == 43 and b == nil)
assert(select("#", t:two()) == 2)
local observed
function t:observe() observed = 44 end
t:observe()
assert(observed == 44)

t.one = function(self) return 45 end
assert(t:one() == 45)
t.two = function(self) return 46, 47 end
a, b = t:two()
assert(a == 46 and b == 47)
assert(select(2, t:two()) == 47)
t.observe = function(self) observed = 48 end
t:observe()
assert(observed == 48)

-- A lookup can invoke __index; its side effects must precede the method body.
local order = {}
local proxy = setmetatable({}, {
    __index = function(self, key)
        order[#order + 1] = "lookup " .. key
        return function(receiver)
            assert(receiver == self)
            order[#order + 1] = "call " .. key
            return 49, nil
        end
    end,
})
assert(proxy:one() == 49)
a, b = proxy:two()
assert(a == 49 and b == nil)
assert(select("#", proxy:all()) == 2)
proxy:statement()
assert(table.concat(order, ",") == "lookup one,call one,lookup two,call two,lookup all,call all,lookup statement,call statement")
print("method lookup order OK")

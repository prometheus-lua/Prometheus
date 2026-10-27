-- Parenthesized calls and varargs always produce exactly one value.
local calls = 0
local function pair() calls = calls + 1; return 1, 2 end
local function noResults() end
local function nilFirst() return nil, 2 end
local function echo(...) return ... end
assert(select("#", (pair())) == 1)
assert(calls == 1) -- Collapsing the results must not evaluate the call again.
local a, b = (pair())
assert(a == 1 and b == nil and calls == 2)
a, b = (pair())
assert(a == 1 and b == nil and calls == 3)
assert(select("#", (noResults())) == 1)
assert(select("#", (nilFirst())) == 1)
assert(echo((nilFirst())) == nil)
assert(select("#", echo("prefix", (pair()))) == 2)
assert(select("#", echo(pair())) == 2)
assert(select("#", echo(noResults())) == 0)

local function first(...) return (...) end
assert(select("#", first(1, 2)) == 1 and first(1, 2) == 1)
assert(select("#", first()) == 1 and first() == nil)
assert(select("#", first(nil, 2)) == 1 and first(nil, 2) == nil)
local function localFirst(...)
    local x, y = (...)
    assert(y == nil)
    x, y = (...)
    assert(y == nil)
    return x
end
assert(localFirst(1, 2) == 1 and localFirst(nil, 2) == nil)
local function returnPair() return (pair()) end
assert(select("#", returnPair()) == 1)

local observed
local object = {
    pair = function(self) return 3, 4 end,
    observe = function(self, ...) observed = select("#", ...) end,
}
assert(select("#", (object:pair())) == 1)
a, b = (object:pair())
assert(a == 3 and b == nil)
local function observe(...) observed = select("#", ...) end
observe((pair()))
assert(observed == 1)
object:observe((pair()))
assert(observed == 1)

local values = {(pair())}
assert(values[1] == 1 and values[2] == nil and values.n == nil)
local function tableFirst(...) return {(...)} end
values = tableFirst(1, 2)
assert(values[1] == 1 and values[2] == nil)
print("parenthesized results OK")

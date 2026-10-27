-- Packed VM argument/return lists must distinguish no values from nil values.
local function echo(...) return ... end
local function noResults() end
local function nilResult() return nil end
assert(select("#", echo()) == 0)
assert(select("#", echo(nil)) == 1)
assert(select("#", echo(1, nil)) == 2)
assert(select("#", echo(nil, nil, nil)) == 3)
assert(select("#", echo(noResults())) == 0)
assert(select("#", echo(nilResult())) == 1)
assert(select("#", echo(tonumber("invalid"))) == 1)
assert(select("#", echo("prefix", echo(nil, nil))) == 3)

local function tail(first, second, ...) return ... end
assert(select("#", tail()) == 0)
assert(select("#", tail(1)) == 0)
assert(select("#", tail(1, 2, nil, nil)) == 2)
local function fixed(first, second) return first, second end
assert(select("#", fixed()) == 2)
assert(select("#", fixed(1, nil)) == 2)

local object = {}
function object:echo(...) assert(self == object); return ... end
assert(select("#", object:echo(nil, nil)) == 2)
assert(select("#", echo(object:echo(1, nil))) == 2)
local observed
function object:observe(...) observed = select("#", ...) end
object:observe(echo(nil, nil))
assert(observed == 2)
local function observe(...) observed = select("#", ...) end
observe(echo(1, nil))
assert(observed == 2)

local a, b, c = echo(nil, 2, nil)
assert(a == nil and b == 2 and c == nil)
local empty = {echo(nil, nil)}
assert(next(empty) == nil) -- Internal counts must not leak into source tables.
local values = {"prefix", echo(nil, "last", nil)}
assert(values[1] == "prefix" and values[2] == nil and values[3] == "last")
assert(values[4] == nil and values.n == nil)
print("nil varargs OK")

--!optimize 1
@native
local function identity<T>(value: T): T return value end
@checked local function add(value: number): number return value + 1 end
@[native, deprecated]
local function old(value) return value end
local anonymous = @native function(value) return value * 2 end
local object = {}
function object:identity<T>(value: T): T return value end
assert(identity<<number>>(7) == 7)
assert(object:identity<<string>>('value') == 'value')
local instantiated = identity<<number>>
assert(instantiated(9) == 9)
local function factory() return identity, 'discarded' end
assert((factory()<<number>>)(11) == 11)
assert(select('#', factory()<<number>>) == 1)
assert(add(4) == 5 and old(3) == 3 and anonymous(5) == 10)
print('Attribute and explicit generic checks passed')

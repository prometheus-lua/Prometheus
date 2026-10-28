-- Type syntax is erased while runtime expressions retain their value counts.
type Name = string
export type Box<T, U = string> = {value: T, tag: U?, [number]: boolean}
type Optional<T> = T | nil
type Callback<T...> = (first: number, T...) -> (string, ...number)
type TableIntersection = {read value: number} & {write name: string}
type function getNumber(ty)
    return types.number
end
type FunctionResult = getNumber<number>
local evaluated = 0
local function observe()
    evaluated += 1
    return {value = 1}
end
type FromTypeof = typeof(observe())

local type = function(value) return value end
local export = 3
local box: Box<number> = {value = 7, tag = 'ok'}
local function identity<T>(value: T, ...: string): T
    return value
end
local anonymous = function<T>(value: T): T return value end
local object = {}
function object:method<T>(value: T): T return value end
local function values(): (number, number) return 11, 22 end
local first, second = values() :: number
local function castVarargs(...: number): number
    return ... :: number
end
local fromTypeFunction: FunctionResult = 0
local total = fromTypeFunction
for i: number = 1, 3 do total += i end
for _, value: number in ipairs({1, 2}) do total += value end
local value = if box.value == 0 then 'zero' elseif box.value == 7 then 'seven' elseif box.value == 8 then 'eight' else 'other'
print(evaluated, export, type(value), anonymous(identity(object:method(box.value))), total, first, second, castVarargs(4, 5))

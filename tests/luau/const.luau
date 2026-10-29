const amount: number, label = 3, 'count'
const data: {count: number} = {count = amount}
data.count += 2
const function factorial(n: number): number
    if n == 0 then return 1 end
    return n * factorial(n - 1)
end
const function closure()
    return function() return amount, label, data.count end
end
local get = closure()
local a, b, c = get()
do
    local amount = 1
    amount = 2
    assert(amount == 2)
end
local previous = 4
const previous = previous + 1
const other, missing = 8, nil
local function produce() return 9 end
const expanded, absent = produce()
local const = function(x) return x + 1 end
local value = const(4)
local tableWithConst = {const = value}
tableWithConst.const += 1
local function asParameter(const)
    const += 2
    return const
end
local total = 0
for const = 1, 3 do total += const end
for const, v in ipairs({4, 5}) do total += const + v end
do
    const const = function(x) return x * 2 end
    total += const(3)
end
print(a, b, c, factorial(5), previous, other, missing)
print(tableWithConst.const, asParameter(3), const(1), expanded, absent, total)

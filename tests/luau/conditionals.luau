local log = ''
local function condition(label, result)
    log ..= label
    return result
end
local function value(label, result)
    log ..= label
    return result
end
local first = if condition('a', false) then value('A', 'bad')
    elseif condition('b', false) then value('B', 'bad')
    elseif condition('c', true) then value('C', false)
    else value('D', true)
local second = if condition('d', false) then 1 elseif condition('e', true) then nil else 3
local third = if true then (if false then 1 elseif true then 2 else 3) else 4
local function pair() return 5, 6 end
local a, b = if true then pair() elseif false then pair() else pair()
print(log, first, second, third, a, b)

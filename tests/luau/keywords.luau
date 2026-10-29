-- Contextual keywords are ordinary names in expressions, bindings, and fields.
local continue, type, export, const = 4, 5, 6, 7
local function names(continue, type, export, const, typeof, read, write)
    return continue + type + export + const + typeof + read + write
end
assert(names(continue, type, export, const, 8, 9, 10) == 49)

local object = {continue = 11, type = 12, export = 13, const = 14}
function object:continue(type)
    return self.type + type
end
assert(object:continue(3) == 15)
function object.export(continue)
    return continue * 2
end
assert(object.export(5) == 10 and object.const == 14)

local sum = 0
for continue = 1, 3 do
    sum += continue
end
for type, export in ipairs({4, 5}) do
    sum += type + export
end
assert(sum == 18)

local calls = 0
do
    local function continue()
        calls += 1
    end
    for i = 1, 4 do
        continue()
        if i % 2 == 0 then continue end
        calls += 10
    end
end
assert(calls == 24)
type Continue = {continue: number, type: number}
export type Export = Continue
local typed: Export = {continue = 1, type = 2}
assert(typed.continue + typed.type == 3)
print('Contextual keyword checks passed')

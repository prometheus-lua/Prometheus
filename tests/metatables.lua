-- Example showcasing metamethod driven vector arithmetic
local Vector = {}
Vector.__index = Vector

function Vector:new(x, y)
    return setmetatable({ x = x, y = y }, self)
end

function Vector.__add(a, b)
    return Vector:new(a.x + b.x, a.y + b.y)
end

function Vector:describe()
    return string.format("(%d,%d)", self.x, self.y)
end

local path = {
    Vector:new(2, 3),
    Vector:new(-1, 4),
    Vector:new(0, -2)
}

local position = Vector:new(0, 0)
for idx, delta in ipairs(path) do
    position = position + delta
    print(string.format("step%d:%s", idx, position:describe()))
end

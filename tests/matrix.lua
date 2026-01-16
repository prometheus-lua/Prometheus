-- Deterministic 2x2 matrix multiplication example
local function multiply(a, b)
    local result = {
        { a[1][1] * b[1][1] + a[1][2] * b[2][1], a[1][1] * b[1][2] + a[1][2] * b[2][2] },
        { a[2][1] * b[1][1] + a[2][2] * b[2][1], a[2][1] * b[1][2] + a[2][2] * b[2][2] }
    }
    return result
end

local A = {
    {1, 2},
    {3, 4}
}

local B = {
    {5, 6},
    {7, 8}
}

local C = multiply(A, B)
for row = 1, 2 do
    print(string.format("%d,%d", C[row][1], C[row][2]))
end

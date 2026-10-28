local t = setmetatable({1}, {
    __metatable = 'locked',
    __iter = function(self) return next, self end,
})
for _, value in t do print(value) end

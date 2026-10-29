local function outer(...)
    return function()
        return ...
    end
end

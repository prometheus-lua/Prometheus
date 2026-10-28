-- @runtime lua51
-- Ending Cff dispatch must not perform a random global/environment lookup.
local originalSetfenv = setfenv
local originalAssert = assert
local function strictEnvironment()
	return setmetatable({}, {
		__index = function(_, key)
			error("unexpected environment lookup: " .. tostring(key), 0)
		end,
	})
end

local function explicitReturn()
	return 42
end
originalSetfenv(explicitReturn, strictEnvironment())
originalAssert(explicitReturn() == 42)

local function fallthrough()
	local value = 1
end
originalSetfenv(fallthrough, strictEnvironment())
originalAssert(fallthrough() == nil)

local function outer()
	local function nested()
		return 7
	end
	return nested
end
originalSetfenv(outer, strictEnvironment())
local nested = outer()
originalAssert(nested() == 7)

-- Also verify the no-error case does not make an extra lookup.
local lookups = {}
local loggingEnv = setmetatable({}, {
	__index = function(_, key)
		lookups[#lookups + 1] = key
		return nil
	end,
})
local function loggedReturn()
	return 9
end
originalSetfenv(loggedReturn, loggingEnv)
originalAssert(loggedReturn() == 9 and #lookups == 0)

print("OK")

local scale = ... or 1

local function make_processor(seed)
	local total = seed
	local function add(_, ...)
		for index = 1, select("#", ...) do
			total = total + select(index, ...)
		end
	end
	return {
		add = add,
		value = function()
			return total
		end,
	}
end

local checksum = 0
for i = 1, 10000 * scale do
	local seed = i % 31
	local processor = make_processor(seed)
	processor:add(i, seed * 2, i % 7)
	checksum = checksum + processor:value()
end

return checksum

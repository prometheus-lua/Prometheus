local scale = ... or 1
local rounds = 100 * scale
local checksum = 0

for round = 1, rounds do
	local records = {}
	for i = 1, 100 do
		local key = (i * 73 + round * 19) % 211
		records[i] = { key = key, value = key * 3 + i }
	end

	table.sort(records, function(left, right)
		if left.key == right.key then
			return left.value < right.value
		end
		return left.key < right.key
	end)

	local subtotal = 0
	for i = 1, #records do
		local record = records[i]
		subtotal = subtotal + record.key * i + record.value
	end
	checksum = checksum + subtotal
end

return checksum

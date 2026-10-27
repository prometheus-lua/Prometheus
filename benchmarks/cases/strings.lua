local scale = ... or 1
local format = string.format
local match = string.match
local checksum = 0

for i = 1, 10000 * scale do
	local category = (i * 17) % 23
	local quantity = (i * 31) % 1000
	local record = format("item:%02d|%04d|zone-%d", category, quantity, i % 9)
	local parsed_category, parsed_quantity, zone = match(record, "^item:(%d+)|(%d+)|zone%-(%d+)$")
	checksum = checksum + tonumber(parsed_category) * 101 + tonumber(parsed_quantity) + tonumber(zone)
end

return checksum

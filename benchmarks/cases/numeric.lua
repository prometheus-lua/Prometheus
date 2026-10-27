local scale = ... or 1
local limit = 180000 * scale
local checksum = 0

for i = 1, limit do
	local value = (i * 37 + 11) % 997
	if value % 5 == 0 then
		checksum = checksum + value * 3
	elseif value % 2 == 0 then
		checksum = checksum + value
	else
		checksum = checksum - value
	end
end

return checksum

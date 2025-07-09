-- Test repeat-until with local variable scoping
-- This should compile without "Unresolved Upvalue" errors
repeat
	local x = 5
until x == 5
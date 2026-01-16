-- Reproduction for issue #203 where the parser misreads the following
-- as arguments to the previous literal assignment.
local counter = 1

(function()
	counter = counter + 1
	print("counter:", counter)
end)();

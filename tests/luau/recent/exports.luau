export local counter = 1
export const fixed = 2
export local optional
export function get() return counter, fixed end
export function increment() counter += 1 end
counter += 2
assert(counter == 3)
local first, second = get()
assert(first == 3 and second == 2)

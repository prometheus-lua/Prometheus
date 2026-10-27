-- Parse once; warm the workload, then measure CPU time per complete invocation.
local input, samples, target = arg[1], tonumber(arg[2]), tonumber(arg[3])
io.stdout:setvbuf('no')
collectgarbage('collect')
local start = os.clock()
local run = assert(loadfile(input))
local loadTime = os.clock() - start
local function checksum()
    local value = run(1)
    assert(type(value) == 'number' or type(value) == 'string', 'scalar checksum required')
    return tostring(value)
end
start = os.clock()
local expected = checksum()
-- Warm up JIT traces and interpreter paths before estimating the batch size.
local elapsed = os.clock() - start
local warmups = 1
while elapsed < target and warmups < 1000 do
    start = os.clock()
    assert(checksum() == expected, 'unstable workload result')
    elapsed = elapsed + os.clock() - start
    warmups = warmups + 1
end
local repeats = math.max(1, math.min(10000,
    math.ceil(target / math.max(elapsed / warmups, 0.000001))))
print('checksum\t' .. expected)
print('load_seconds\t' .. string.format('%.9f', loadTime))
print('repeats\t' .. repeats)
for sample = 1, samples do
    collectgarbage('collect')
    start = os.clock()
    for _ = 1, repeats do
        assert(checksum() == expected, 'unstable workload result')
    end
    print('seconds\t' .. string.format('%.9f', (os.clock() - start) / repeats))
end

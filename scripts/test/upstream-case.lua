-- Preserve references: upstream cases deliberately modify environments/globals.
local check, load, globals = assert, loadfile, _G
local stdout, write, flush = io.stdout, io.stdout.write, io.stdout.flush
local wrap = coroutine.wrap
local file, protocol = arg[1], arg[2]
math.randomseed(0)
check(os.setlocale("C"))
collectgarbage("setstepmul", 180)
collectgarbage("setpause", 190)
package.path = "?;./?.lua;" .. package.path
T = nil
Message = function(message) print(message) end
local chunk = check(load(file))
if protocol == "big" then
    local co = wrap(chunk)
    check(co() == "b", "big.lua must yield b")
    check(co() == "a", "big.lua must return a")
elseif protocol == "calls" then
    local result = chunk()
    check(result and result == globals.deep, "calls.lua must return deep")
elseif protocol ~= "none" then
    check(chunk() == tonumber(protocol), "unexpected upstream return value")
else
    chunk()
end
write(stdout, "\nPROMETHEUS_UPSTREAM_COMPLETE\n")
flush(stdout)

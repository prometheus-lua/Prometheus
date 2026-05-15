-- This Test is Part of the Prometheus Obfuscator by levno-710
--
-- primes.lua
--
-- This Test demonstrates a deterministic prime number generator.

local function primes(n)
    local function isPrime(n)
        for i = 2, math.sqrt(n) do
            if n % i == 0 then
                return false
            end
        end
        return true
    end
    for i = 2, n do
        if isPrime(i) then
            print(i)
        end
    end
end

primes(20)
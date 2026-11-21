-- Source text for the operand-decrypt cipher, inlined into the generated
-- VM interpreter by vm/runtime.lua. Must stay arithmetically identical to
-- vm/encrypt_operands.lua's bxor32/rotl32/mix/keystream -- both sides are
-- the same algorithm, one run once at build time to encrypt, the other run
-- every single instruction at run time to decrypt.
--
-- __CIPHER_MASK__, __CIPHER_PRIME1__, __CIPHER_PRIME2__, __CIPHER_PRIME3__
-- are substituted by vm/runtime.lua from the same constants
-- vm/encrypt_operands.lua uses, so a future change to those constants only
-- has to happen in one place.
-- 
-- Some operands are negative (CALL/TAILCALL's -1/0/1 result-mode
-- flag); bxor32/mix work purely in [0, 2^32) bit patterns, so a
-- decrypted operand must be folded back from that unsigned range to
-- the signed value the rest of the interpreter compares against.
return [==[
local __hBxor32, __hRotl32, __hMix, __hKeystream, __hToSigned32
do
    local hFloor = math.floor
    local hMASK, hP1, hP2, hP3 = __CIPHER_MASK__, __CIPHER_PRIME1__, __CIPHER_PRIME2__, __CIPHER_PRIME3__
    function __hBxor32(a, b)
        a, b = a % hMASK, b % hMASK
        local result, bit = 0, 1
        while a > 0 or b > 0 do
            local abit, bbit = a % 2, b % 2
            if abit ~= bbit then result = result + bit end
            a, b = (a - abit) / 2, (b - bbit) / 2
            bit = bit * 2
        end
        return result
    end
    function __hRotl32(x, r)
        x = x % hMASK
        local hi = hFloor(x / 2 ^ (32 - r))
        local lo = (x * 2 ^ r) % hMASK
        return (lo + hi) % hMASK
    end
    function __hMix(h, value)
        value = value % hMASK
        h = __hBxor32(h, value)
        h = (h * hP1) % hMASK
        h = __hBxor32(h, hFloor(h / 65536))
        h = (h * hP2) % hMASK
        h = __hBxor32(h, hFloor(h / 32771))
        h = (h + hP3) % hMASK
        return __hRotl32(h, 13)
    end
    function __hKeystream(h)
        local k = __hBxor32(h, hFloor(h / 15))
        k = (k * hP2) % hMASK
        return __hBxor32(k, hFloor(k / 13))
    end
    function __hToSigned32(value)
        value = value % hMASK
        if value >= hMASK / 2 then
            return value - hMASK
        end
        return value
    end
end
]==]

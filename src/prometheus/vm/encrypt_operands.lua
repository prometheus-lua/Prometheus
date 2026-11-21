-- Encrypts VM instruction operands with a running keystream chained off each
-- previously-decrypted operand's own value, so operands exist in cleartext
-- only transiently during execution and never in the emitted data or in any
-- static per-instruction table. Intended to run after vm/optimize.lua (so
-- PCs, and therefore JMP/JFALSE/JTRUE targets, are final) and before
-- vm/emit.lua (so it sees plain IR instructions, not the shuffled, per-build
-- operand/opcode layout that Layout:encode applies just before unparsing).
--
-- Cipher: an arithmetic-only 32-bit mix, mirrored exactly (as a Lua source
-- template, see vm/runtime_cipher.lua) inside the generated interpreter, so
-- decryption happens identically at runtime with no native bitwise
-- operators -- the Lua 5.1 target this project emits for has none.
local opcodes = require('prometheus.vm.opcodes')
local signature = require('prometheus.vm.operand_signature')

-- proto.code stores numeric opcode IDs (vm/compiler.lua emits opcodes[op]
-- directly); recover the name so operand_signature.lua can be indexed by it.
local opcodeNames = {}
for name, id in pairs(opcodes) do opcodeNames[id] = name end

-- A pure forward chain across the whole instruction stream only gives a
-- well-defined decrypt key when every instruction is reached exactly one
-- way. Any join point -- a jump target, or the PC right after a jump, that
-- more than one edge can reach -- breaks that: the runtime's running hash
-- reflects whichever path was actually taken, but each instruction's
-- operands were encrypted against only one specific prior state. So the
-- chain is instead reset at every basic-block leader (this mirrors the
-- leader computation vm/optimize.lua already does for its own passes) and
-- only ever threaded *within* a block, where a single entry point means
-- the incoming state is unambiguous regardless of how that block was
-- reached. Each instruction still extends the chain for every later
-- instruction in the same block, exactly as specified; blocks simply
-- bound how far any one chain runs.
local function computeLeaders(code)
    local count = #code
    local leaders = {[1] = true, [count + 1] = true}
    for pc, instruction in ipairs(code) do
        local op = opcodeNames[instruction[1]]
        if op == 'JMP' then
            leaders[pc + 1] = true; leaders[instruction[2]] = true
        elseif op == 'JTRUE' or op == 'JFALSE' then
            leaders[pc + 1] = true; leaders[instruction[3]] = true
        elseif op == 'RETURN' or op == 'RETURN0' or op == 'RETURN1'
            or op == 'RETURN2' or op == 'RETURN3' or op == 'TAILCALL'
            or op == 'TAILCALL0' or op == 'TAILCALL1' or op == 'TAILCALL2'
            or op == 'TAILCALL3' then
            leaders[pc + 1] = true
        end
    end
    return leaders
end

local MASK = 4294967296 -- 2^32
local PRIME1, PRIME2, PRIME3 = 2654435761, 2246822519, 3266489917
local floor = math.floor

local function bxor32(a, b)
    a, b = a % MASK, b % MASK
    local result, bit = 0, 1
    while a > 0 or b > 0 do
        local abit, bbit = a % 2, b % 2
        if abit ~= bbit then result = result + bit end
        a, b = (a - abit) / 2, (b - bbit) / 2
        bit = bit * 2
    end
    return result
end

local function rotl32(x, r)
    x = x % MASK
    local hi = floor(x / 2 ^ (32 - r))
    local lo = (x * 2 ^ r) % MASK
    return (lo + hi) % MASK
end

-- Operands are not all non-negative: CALL/TAILCALL's trailing result-count
-- flag is one of {-1, 0, 1} (variable results, none, or a known fixed
-- count). bxor32/mix only ever see or produce values in [0, 2^32), the
-- two's-complement bit pattern of a 32-bit int -- -1 and 4294967295 are the
-- same bits. Encrypting must fold a negative operand's bit pattern in
-- (toUnsigned32), and decrypting must fold the bit pattern back out to the
-- signed value the rest of the interpreter actually compares against
-- (toSigned32) -- otherwise a decrypted -1 comes back as 4294967295, which
-- is numerically different even though every bit matches.
local function toUnsigned32(value)
    return value % MASK
end

local function toSigned32(value)
    value = value % MASK
    if value >= MASK / 2 then
        return value - MASK
    end
    return value
end

-- Folds one plaintext operand value into the running hash state. Any real
-- number is accepted (operands are always non-negative integers in
-- practice: register slots, constant indices, child/jump indices, or the
-- small {-1,0,1} CALL result-mode flag), so the value is reduced mod 2^32
-- before mixing to keep every intermediate an exact double.
local function mix(h, value)
    value = value % MASK
    h = bxor32(h, value)
    h = (h * PRIME1) % MASK
    h = bxor32(h, floor(h / 65536))
    h = (h * PRIME2) % MASK
    h = bxor32(h, floor(h / 32771))
    h = (h + PRIME3) % MASK
    return rotl32(h, 13)
end

-- Derives this step's keystream word from the current hash state. Kept
-- separate from mix() so encrypting an operand does not itself perturb the
-- state used to decrypt it -- the state only advances once the operand's
-- plaintext value is folded in via mix(), after the XOR is applied.
local function keystream(h)
    local k = bxor32(h, floor(h / 15))
    k = (k * PRIME2) % MASK
    return bxor32(k, floor(k / 13))
end

local Encrypt = {}

-- Seeds one prototype's cipher. Each prototype (top-level chunk and every
-- nested function) gets its own independent chain, started from an
-- unpredictable per-build seed, so nothing about one function's operands
-- can be inferred from another's.
function Encrypt.seed()
    return math.random(0, MASK - 1)
end

-- Encrypts one prototype's instruction stream in place, in final PC order,
-- then recurses into children (each with its own seed), storing each
-- prototype's seed as proto.operandSeed so the emitter carries it into the
-- data the generated interpreter reads at startup.
--
-- The running state h starts at the prototype's seed (itself an opaque
-- number baked into the emitted data, not a secret derived at runtime) and
-- advances exactly once per plain-numeric operand, in instruction order,
-- regardless of opcode. 'X' (opaque, non-numeric) operand slots are left
-- untouched and do not advance h -- a table has no single plaintext value
-- to fold in, and skipping it keeps the runtime decrypt loop a fixed,
-- opcode-driven sequence of XORs with no conditional structure to branch on.
function Encrypt.apply(proto)
    local seed = Encrypt.seed()
    local leaders = computeLeaders(proto.code)
    local h = seed
    for pc, instruction in ipairs(proto.code) do
        if leaders[pc] then h = seed end
        local name = opcodeNames[instruction[1]]
        local shape = assert(signature[name],
            'EncryptOperands: no operand signature for opcode ' .. tostring(name))
        for position = 1, #shape do
            if shape[position] == 'N' then
                local slot = position + 1 -- instruction[1] is the opcode
                local plain = instruction[slot]
                if plain ~= nil then
                    instruction[slot] = bxor32(plain, keystream(h))
                    h = mix(h, plain)
                end
            end
        end
    end
    -- The leader set itself: which PCs must reseed h = seed before
    -- decrypting. This is the only static per-instruction information the
    -- cipher relies on (one bit per PC, carried as its own prototype field
    -- rather than a variable-position extra operand, since IR instructions
    -- already vary in length per opcode and Layout:encode's fixed 2..5
    -- operand slots have no room for a fifth, opcode-dependent element).
    -- It says nothing about any operand's value, only where block
    -- boundaries fall -- information control-flow structure already
    -- reveals on its own.
    proto.operandLeaders = leaders
    -- Stored as plain prototype metadata (alongside maxRegister etc.); the
    -- seed is not a secret by itself -- without re-running the exact chain
    -- of decrypts the interpreter performs, it reveals nothing about any
    -- individual operand's plaintext.
    proto.operandSeed = seed
    for _, child in ipairs(proto.children or {}) do
        Encrypt.apply(child)
    end
end

Encrypt.bxor32 = bxor32
Encrypt.rotl32 = rotl32
Encrypt.mix = mix
Encrypt.keystream = keystream
Encrypt.toUnsigned32 = toUnsigned32
Encrypt.toSigned32 = toSigned32
Encrypt.MASK = MASK
Encrypt.PRIME1 = PRIME1
Encrypt.PRIME2 = PRIME2
Encrypt.PRIME3 = PRIME3

return Encrypt

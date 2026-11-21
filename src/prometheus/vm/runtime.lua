-- Builds the Lua 5.1 runtime used by the bytecode emitter. The emitter replaces
-- __PROTOTYPES__ with the startup reconstruction call before parsing the source.
local dispatch = require("prometheus.vm.runtime_dispatch")
local decryptDispatch = require("prometheus.vm.runtime_decrypt")
local cipherSource = require("prometheus.vm.runtime_cipher")
local Encrypt = require("prometheus.vm.encrypt_operands")
local Layout = require("prometheus.vm.layout")

local Runtime = {}

-- Do not query `getfenv(wrapper)` from the wrapper body: that self-reference
-- forms a closure cycle that Cff can keep alive after the wrapper is discarded.
local template = [=[
return (function(prototypes, ...)
local nativeGetfenv, nativeSetfenv = getfenv, setfenv
local nativeUnpack = unpack or table.unpack
local nativeTonumber, nativeError = tonumber, error
local nativeSelect, nativeIpairs = select, ipairs

local function pack(...)
    return { [__COUNT_KEY__] = nativeSelect("#", ...), ... }
end

__CIPHER_FUNCTIONS__

local make

local function loop(P, U, Env, R, V)
    local code, K = P[__FIELD_code__], P[__FIELD_constants__]
    local pc = 1
    local I, opcode, a, b, c, d, x, y, z
    __OPERAND_HASH_INIT__
    while true do
        I = code[pc]
        __OPERAND_HASH_RESEED__
        pc = pc + 1
        opcode = I[1]
        __FETCH_OPERANDS__
        __DECRYPT_OPERANDS__
        __DISPATCH__
        I, opcode, a, b, c, d, x, y, z = nil, nil, nil, nil, nil, nil, nil, nil, nil
    end
end

local function start(P, U, Env, ...)
    local R
    local params = P[__FIELD_params__]
    local V
    if not P[__FIELD_vararg__] and #params <= 3 then
        R = {}
        local argc = nativeSelect("#", ...)
        for i = 1, #params do
            local param = params[i]
            local value
            if i <= argc then value = nativeSelect(i, ...) end
            if param[2] then
                R[param[1]] = { value }
            else
                R[param[1]] = value
            end
        end
    else
        local incoming = pack(...)
        R = {}
        for i = 1, #params do
            local param = params[i]
            local value = incoming[i]
            if param[2] then
                R[param[1]] = { value }
            else
                R[param[1]] = value
            end
        end
        V = { [__COUNT_KEY__] = 0 }
        if P[__FIELD_vararg__] then
            local first = #params + 1
            if incoming[__COUNT_KEY__] > #params then
                V[__COUNT_KEY__] = incoming[__COUNT_KEY__] - #params
            end
            for i = 1, V[__COUNT_KEY__] do
                V[i] = incoming[first + i - 1]
            end
        end
        incoming = nil
    end
    return loop(P, U, Env, R, V)
end

make = function(P, U, inheritedEnv)
    local wrapper
    if nativeGetfenv and nativeSetfenv then
        wrapper = function(...)
            local Env = nativeGetfenv(1)
            return start(P, U, Env, ...)
        end
        nativeSetfenv(wrapper, inheritedEnv)
    else
        wrapper = function(...)
            return start(P, U, inheritedEnv, ...)
        end
    end
    return wrapper
end

local entryEnv = nativeGetfenv and nativeGetfenv(1) or _ENV or _G
return make(prototypes[1], {}, entryEnv)(...)
end)(__PROTOTYPES__, ...)
]=]

-- encryptOperands selects, at generation time, whether the interpreter
-- carries the operand cipher at all. When false (the default, and what
-- every existing preset still gets), __DECRYPT_OPERANDS__ and
-- __CIPHER_FUNCTIONS__ expand to nothing: no seed/leader locals, no XOR,
-- no behavior change whatsoever versus the pre-cipher runtime. This must
-- be a build-time choice rather than a per-instruction runtime check --
-- a disabled cipher has to generate code that cannot touch an operand,
-- not code that asks every single instruction not to.
function Runtime.build(layout, encryptOperands)
    layout = layout or Layout.new()
    local operands = layout.operands
    local fetch = "a, b, c, d = I[" .. tostring(operands[1]) .. "], I["
        .. tostring(operands[2]) .. "], I[" .. tostring(operands[3]) .. "], I["
        .. tostring(operands[4]) .. "]"
    local cipherFunctions, decrypt, hashInit, hashReseed = '', '', '', ''
    if encryptOperands then
        cipherFunctions = cipherSource
            :gsub('__CIPHER_MASK__', tostring(Encrypt.MASK))
            :gsub('__CIPHER_PRIME1__', tostring(Encrypt.PRIME1))
            :gsub('__CIPHER_PRIME2__', tostring(Encrypt.PRIME2))
            :gsub('__CIPHER_PRIME3__', tostring(Encrypt.PRIME3))
        decrypt = decryptDispatch.build(layout.opcodes)
        -- Per-activation cipher state: reseeded from the prototype's seed
        -- at startup and again on entry to every basic block (a block can
        -- be reached along more than one control-flow edge, and only a
        -- single, path-independent starting state gives every instruction
        -- in it one well-defined key). Within a block it just keeps
        -- advancing, each decrypted operand feeding the key for the next.
        -- Nothing here exists except as a local inside this one call.
        hashInit = 'local __vmOperandSeed = P[' .. tostring(layout.fields.operandSeed) .. '] or 0\n'
            .. '    local __vmOperandLeaders = P[' .. tostring(layout.fields.operandLeaders) .. ']\n'
            .. '    local __vmOperandHash = __vmOperandSeed'
        hashReseed = 'if __vmOperandLeaders and __vmOperandLeaders[pc] then __vmOperandHash = __vmOperandSeed end'
    end
    local source = template:gsub("__FETCH_OPERANDS__", function()
        return fetch
    end):gsub("__DECRYPT_OPERANDS__", function()
        return decrypt
    end):gsub("__DISPATCH__", function()
        return dispatch.build(layout.opcodes)
    end):gsub("__CIPHER_FUNCTIONS__", function()
        return cipherFunctions
    end):gsub("__OPERAND_HASH_INIT__", function()
        return hashInit
    end):gsub("__OPERAND_HASH_RESEED__", function()
        return hashReseed
    end)
    source = source:gsub('__FIELD_(%w+)__', function(name)
        return tostring(assert(layout.fields[name], 'Missing VM prototype key'))
    end):gsub('__COUNT_KEY__', function() return tostring(layout.countKey) end)
    return source
end

return Runtime

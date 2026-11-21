-- Builds the Lua source for decrypting VM instruction operands at runtime,
-- in lockstep with vm/encrypt_operands.lua's compile-time pass. For every
-- opcode, decrypts exactly the operand slots that opcode's entry in
-- operand_signature.lua marks numeric ('N'), each against the keystream
-- derived from the running per-prototype hash state h, then folds that same
-- (now-decrypted) plaintext value into h so it becomes part of the key for
-- the next numeric operand anywhere in the stream -- across instructions,
-- across jumps, across loop iterations. There is no per-PC key table: h
-- only ever exists as a transient local in the interpreter loop, rebuilt
-- from the prototype's seed at the start of every call and advanced solely
-- by the chain of values actually decrypted along the path execution took.
--
-- Operand slots not marked 'N' (table-valued operands such as ARGS' and
-- CALLn/TAILCALLn's register lists, and CLEARS' register list) are left
-- exactly as fetched: there is nothing to decrypt and nothing to fold in,
-- so they neither consume nor advance the keystream.
local opcodes = require('prometheus.vm.opcodes')
local signature = require('prometheus.vm.operand_signature')

local M = {}

local slotName = {[1] = 'a', [2] = 'b', [3] = 'c', [4] = 'd'}

function M.build(layoutOpcodes)
    local entries = {}
    for name, id in pairs(layoutOpcodes) do
        entries[#entries + 1] = {name = name, id = id}
    end
    table.sort(entries, function(left, right) return left.id < right.id end)

    local function body(name)
        local shape = assert(signature[name],
            'EncryptOperands: no operand signature for opcode ' .. tostring(name))
        local lines = {}
        for position = 1, #shape do
            if shape[position] == 'N' then
                local var = slotName[position]
                -- XOR recovers the operand's unsigned 32-bit bit pattern;
                -- fold that (not yet sign-corrected) value into h, since
                -- that is exactly what encryption folded in on the other
                -- side, then convert to the signed value the dispatch
                -- bodies actually compare and index with (e.g. CALL's
                -- -1/0/1 result-mode flag).
                lines[#lines + 1] = var .. ' = __hBxor32(' .. var .. ', __hKeystream(__vmOperandHash))'
                lines[#lines + 1] = '__vmOperandHash = __hMix(__vmOperandHash, ' .. var .. ')'
                lines[#lines + 1] = var .. ' = __hToSigned32(' .. var .. ')'
            end
        end
        if #lines == 0 then return nil end
        return table.concat(lines, '\n')
    end

    local function indent(source, prefix)
        return prefix .. source:gsub('\n', '\n' .. prefix)
    end

    local function emit(first, last, depth)
        local prefix = string.rep('    ', depth)
        if first == last then
            local entry = entries[first]
            local decrypt = body(entry.name)
            if not decrypt then return prefix .. '-- opcode ' .. tostring(entry.id) .. ' has no numeric operands' end
            return prefix .. 'if opcode == ' .. tostring(entry.id) .. ' then\n'
                .. indent(decrypt, prefix .. '    ') .. '\n'
                .. prefix .. 'end'
        end
        local middle = math.floor((first + last) / 2)
        local split = entries[middle].id
        return prefix .. 'if opcode <= ' .. tostring(split) .. ' then\n'
            .. emit(first, middle, depth + 1) .. '\n'
            .. prefix .. 'else\n'
            .. emit(middle + 1, last, depth + 1) .. '\n'
            .. prefix .. 'end'
    end

    assert(#entries > 0, 'No VM opcodes registered')
    return emit(1, #entries, 0)
end

return M

-- Conservative, basic-block-local peephole passes for VM prototypes.
local opcodes = require('prometheus.vm.opcodes')
local names = {}
for name, id in pairs(opcodes) do names[id] = name end

local function name(ins) return names[ins[1]] end
local function copy(ins)
    local result = {}
    for i = 1, #ins do result[i] = ins[i] end
    return result
end
local function isUnary(op) return op == 'NOT' or op == 'NEG' or op == 'LEN' end
local function isBinary(op)
    return op == 'ADD' or op == 'SUB' or op == 'MUL' or op == 'DIV'
        or op == 'MOD' or op == 'POW' or op == 'CONCAT' or op == 'LT'
        or op == 'LE' or op == 'GT' or op == 'GE' or op == 'EQ' or op == 'NE'
end
local function producer(ins)
    local op = name(ins)
    if op == 'LOAD' or op == 'NIL' or op == 'GLOBAL' or op == 'GETUP'
        or op == 'GETCELL' or op == 'GETTABLE' or op == 'NOT' or op == 'NEG'
        or op == 'LEN' or isBinary(op) then return ins[2] end
    if op == 'CALL' or op == 'CALL0' or op == 'CALL1' or op == 'CALL2' or op == 'CALL3' then
        if ins[5] == 1 then return ins[2] end
    end
end
local function terminal(op)
    return op == 'JMP' or op == 'RETURN' or op == 'TAILCALL'
        or op == 'RETURN0' or op == 'RETURN1' or op == 'RETURN2' or op == 'RETURN3'
        or op == 'TAILCALL0' or op == 'TAILCALL1' or op == 'TAILCALL2' or op == 'TAILCALL3'
end

-- Track only values proven nil. An unknown writer invalidates the proof.
local function updateNil(state, ins)
    local op = name(ins)
    if op == 'CLEAR' then state[ins[2]] = true; return end
    if op == 'CLEARS' then
        for _, reg in ipairs(ins[2] or {}) do state[reg] = true end
        return
    end
    if op == 'NIL' then state[ins[2]] = true; return end
    if op == 'MOVE' then
        state[ins[2]] = state[ins[3]] and true or nil
        return
    end
    if op == 'JTRUE' or op == 'JFALSE' then state[ins[2]] = true; return end
    if op == 'FORPREP' then state[ins[2]], state[ins[3]], state[ins[4]] = nil, nil, nil; return end
    if op == 'FORCHECK' then state[ins[2]] = nil; return end
    if op == 'EXPAND' then return end -- Writes table fields, not VM registers.
    local writes = op == 'LOAD' or op == 'NIL' or op == 'MOVE' or op == 'CELL'
        or op == 'GETCELL' or op == 'GETUP' or op == 'GLOBAL' or op == 'GETTABLE'
        or op == 'TABLE' or op == 'ARGS' or op == 'TAKE' or op == 'VARARG'
        or op == 'CLOSURE' or isUnary(op) or isBinary(op)
    if op == 'CALL' or op == 'CALL0' or op == 'CALL1' or op == 'CALL2' or op == 'CALL3' then
        if ins[5] == 0 then return end
        state[ins[2]] = nil; return
    end
    if writes then state[ins[2]] = nil; return end
    if op == 'JMP' or op == 'SETCELL' or op == 'SETUP' or op == 'SETGLOBAL'
        or op == 'SETTABLE' or op == 'TAILCALL' or op == 'TAILCALL0'
        or op == 'TAILCALL1' or op == 'TAILCALL2' or op == 'TAILCALL3'
        or op == 'RETURN' or op == 'RETURN0' or op == 'RETURN1'
        or op == 'RETURN2' or op == 'RETURN3' then return end
    for reg in pairs(state) do state[reg] = nil end
end

local function initialNil(proto, first)
    local state = {}
    if first == 1 then
        -- A back edge to the first block can carry values from an earlier pass.
        for _, instruction in ipairs(proto.code) do
            local op = name(instruction)
            if (op == 'JMP' and instruction[2] == 1)
                or ((op == 'JTRUE' or op == 'JFALSE') and instruction[3] == 1) then
                return state
            end
        end
        for reg = 1, proto.maxRegister or 0 do state[reg] = true end
        for _, param in ipairs(proto.params or {}) do state[param[1]] = nil end
    end
    return state
end
local function rewriteBlock(block, proto)
    local result, state, i = {}, initialNil(proto, block[1].pc), 1
    local function emit(item)
        result[#result + 1] = item
        updateNil(state, item.ins)
    end
    while i <= #block do
        local item, ins = block[i], block[i].ins
        local dst = producer(ins)
        if dst and state[dst] then
            local moveAt = i + 1
            while moveAt <= #block and name(block[moveAt].ins) == 'CLEAR' do
                moveAt = moveAt + 1
            end
            if moveAt <= #block and name(block[moveAt].ins) == 'MOVE'
                and block[moveAt].ins[3] == dst then
                local target, ok = block[moveAt].ins[2], true
                if target == dst then ok = false end
                for j = i + 1, moveAt - 1 do
                    local reg = block[j].ins[2]
                    if reg == dst or reg == target then ok = false end
                end
                local last, found = moveAt + 1, false
                while ok and last <= #block and name(block[last].ins) == 'CLEAR' do
                    local reg = block[last].ins[2]
                    if reg == target then ok = false end
                    if reg == dst then found = true; break end
                    last = last + 1
                end
                if ok and found then
                    local changed = copy(ins); changed[2] = target
                    emit({pc = item.pc, ins = changed})
                    for j = i + 1, moveAt - 1 do emit(block[j]) end
                    for j = moveAt + 1, last do
                        if block[j].ins[2] ~= dst then emit(block[j]) end
                    end
                    i = last + 1
                else
                    emit(item); i = i + 1
                end
            else
                emit(item); i = i + 1
            end
        elseif name(ins) == 'MOVE' then
            local temp, source = ins[2], ins[3]
            local consumer = i + 1
            if temp ~= source and state[temp] then
                while consumer <= #block do
                    local pure = name(block[consumer].ins)
                    if pure ~= 'LOAD' and pure ~= 'NIL' then break end
                    local written = block[consumer].ins[2]
                    if written == temp or written == source then break end
                    consumer = consumer + 1
                end
                if consumer <= #block then
                    local use, useOp = block[consumer].ins, name(block[consumer].ins)
                    local used = isUnary(useOp) and use[3] == temp
                        or isBinary(useOp) and (use[3] == temp or use[4] == temp)
                    if used and use[2] ~= temp then
                        local last, found = consumer + 1, false
                        while last <= #block and name(block[last].ins) == 'CLEAR' do
                            if block[last].ins[2] == temp then found = true; break end
                            last = last + 1
                        end
                        if found then
                            -- The removed MOVE's destination is known nil and stays nil.
                            for j = i + 1, consumer - 1 do emit(block[j]) end
                            local changed = copy(use)
                            if changed[3] == temp then changed[3] = source end
                            if changed[4] == temp then changed[4] = source end
                            emit({pc = block[consumer].pc, ins = changed})
                            for j = consumer + 1, last do
                                if block[j].ins[2] ~= temp then emit(block[j]) end
                            end
                            i = last + 1
                        else
                            emit(item); i = i + 1
                        end
                    else
                        emit(item); i = i + 1
                    end
                else
                    emit(item); i = i + 1
                end
            else
                emit(item); i = i + 1
            end
        else
            emit(item); i = i + 1
        end
    end
    return result
end

local function compactBlock(block, proto, output)
    local state = initialNil(proto, block[1].pc)
    local pending = {}
    local function flush()
        if #pending > 0 then
            if #pending > 1 and opcodes.CLEARS then
                local regs, pcs = {}, {}
                for _, item in ipairs(pending) do regs[#regs + 1] = item.ins[2]; pcs[#pcs + 1] = item.pc end
                output[#output + 1] = {ins = {opcodes.CLEARS, regs}, pcs = pcs}
            else
                for _, item in ipairs(pending) do output[#output + 1] = {ins = item.ins, pcs = {item.pc}} end
            end
            pending = {}
        end
    end
    for _, item in ipairs(block) do
        local ins = item.ins
        if name(ins) == 'CLEAR' then
            local reg = ins[2]
            if not state[reg] then pending[#pending + 1] = item; state[reg] = true end
        else
            flush()
            updateNil(state, ins)
            output[#output + 1] = {ins = ins, pcs = {item.pc}}
        end
    end
    flush()
end

local function optimizeCode(proto)
    local code, count = proto.code, #proto.code
    if count == 0 then return end
    local leaders = {[1] = true, [count + 1] = true}
    for pc, ins in ipairs(code) do
        local op = name(ins)
        if op == 'JMP' then
            leaders[pc + 1] = true; leaders[ins[2]] = true
        elseif op == 'JTRUE' or op == 'JFALSE' then
            leaders[pc + 1] = true; leaders[ins[3]] = true
        elseif terminal(op) then leaders[pc + 1] = true end
    end
    local starts = {}
    for pc = 1, count + 1 do if leaders[pc] then starts[#starts + 1] = pc end end
    local output, oldToNew = {}, {}
    for b = 1, #starts - 1 do
        local first, last = starts[b], starts[b + 1] - 1
        local block = {}
        for pc = first, last do block[#block + 1] = {pc = pc, ins = code[pc]} end
        block = rewriteBlock(block, proto)
        local before = #output
        compactBlock(block, proto, output)
        -- Map retained and batched original instructions to their emitted PC.
        for index = before + 1, #output do
            local entry = output[index]
            for _, pc in ipairs(entry.pcs) do oldToNew[pc] = index end
        end
        local nextPc = #output + 1
        for pc = last, first, -1 do
            if oldToNew[pc] then nextPc = oldToNew[pc] else oldToNew[pc] = nextPc end
        end
    end
    oldToNew[count + 1] = #output + 1
    for _, entry in ipairs(output) do
        local ins, op = entry.ins, name(entry.ins)
        if op == 'JMP' then ins[2] = oldToNew[ins[2]]
        elseif op == 'JTRUE' or op == 'JFALSE' then ins[3] = oldToNew[ins[3]] end
    end
    local compact = {}
    for _, entry in ipairs(output) do compact[#compact + 1] = entry.ins end
    proto.code = compact
end

local function optimize(proto)
    for _, child in ipairs(proto.children or {}) do optimize(child) end
    optimizeCode(proto)
    return proto
end

return optimize

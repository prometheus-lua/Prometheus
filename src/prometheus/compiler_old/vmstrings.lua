-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- vmstrings.lua
-- This Script contains Constant Strings used in the Bytecode vm

local InstructionKind = require("prometheus.compiler_old.instructionkind");
local util = require("prometheus.util");

-- Inline Replacements needed:
-- CONST_INSTRUCTION_KEY_1 = The first 8 bit of the Xor key for the instructions
-- CONST_INSTRUCTION_KEY_2 = The second 8 bit of the Xor key for the instructions
-- CONST_INSTRUCTION_KEY_3 = The third 8 bit of the Xor key for the instructions
-- CONST_INSTRUCTION_KEY_4 = The fourth 8 bit of the Xor key for the instructions
-- CONST_STRING            = The Header Byte Indicating that a const is a String
-- CONST_DOUBLE            = The Header Byte Indicating that a const is a Double

local instructions = {
    -- LOADCONST Instruction Code
    [InstructionKind.LOADCONST] = [[
        tmp3 = readU(pos + 1, 3, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3, CONST_INSTRUCTION_KEY_4);
        stackl = stackl + 1;
        stack[stackl] = constantTable[tmp3];
        if not stack[stackl] then
            tmp = constPosTable[tmp3] + constOffset;
            tmp2 = bytes[tmp];
            if  tmp2 == CONST_STRING then
                tmp2 = readU(tmp + 1, 4); -- String length
                stack[stackl] = "";
                for tmp2=1,tmp2, 1 do
                stack[stackl] = stack[stackl] .. strchar(bytes[tmp + tmp2 + 4])
                end
            elseif tmp2 == CONST_DOUBLE then
                stack[stackl] = readD(tmp + 1);
            elseif tmp2 == CONST_U32 then
                stack[stackl] = readU(tmp + 1, 4);
            elseif tmp2 == CONST_N32 then
                stack[stackl] = -readU(tmp + 1, 4);
            end
            constantTable[tmp3] = stack[stackl];
        end
    ]];

    -- GETGLOBAL Instruction Code
    [InstructionKind.GETGLOBAL] = [=[
        stack[stackl] = env[stack[stackl]];
    ]=];

    -- SETGLBOAL Instruction Code
    [InstructionKind.SETGLOBAL] = [=[
        stackl = stackl - 2;
        env[stack[stackl + 1]] = stack[stackl + 2];
        stack[stackl + 1], stack[stackl + 2] = nil, nil;
    ]=];

    -- ASSIGNGLOBAL Instruction Code
    [InstructionKind.ASSIGNGLOBAL] = [=[
        stackl = stackl - 1;
        env[stack[stackl + 1]] = stack[stackl][readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)];
        stack[stackl + 1] = nil;
    ]=];

    -- GETLOCAL Instruction Code
    [InstructionKind.GETLOCAL] = [=[
        tmp = locals;
        for tmp2 = 1, readU(pos + 3, 1, CONST_INSTRUCTION_KEY_4), 1 do
            tmp = tmp[0];
        end
        stack[stackl + 1] = tmp[readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)];
        stackl = stackl + 1;
    ]=];

    -- SETLOCAL Instruction Code
    [InstructionKind.SETLOCAL] = [=[
        tmp = locals;
        for tmp2 = 1, readU(pos + 3, 1, CONST_INSTRUCTION_KEY_4), 1 do
            tmp = tmp[0];
        end
        tmp[readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)] = stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- ASSIGNLOCAL Instruction Code
    [InstructionKind.ASSIGNLOCAL] = [=[
        tmp = locals;
        for tmp2 = 1, readU(pos + 3, 1, CONST_INSTRUCTION_KEY_4), 1 do
            tmp = tmp[0];
        end
        tmp[readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)] = stack[stackl - 1][stack[stackl]];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- DUP Instruction Code
    [InstructionKind.DUP] = [=[
        stack[stackl + 1] = stack[stackl];
        stackl = stackl + 1;
    ]=];

    -- LOADNIL Instruction Code
    [InstructionKind.LOADNIL] = [=[
        stack[stackl + 1] = nil;
        stackl = stackl + 1;
    ]=];

    -- LOADFALSE Instruction Code
    [InstructionKind.LOADFALSE] = [=[
        stack[stackl + 1] = false;
        stackl = stackl + 1;
    ]=];

    -- LOADTRUE Instruction Code
    [InstructionKind.LOADTRUE] = [=[
        stack[stackl + 1] = true;
        stackl = stackl + 1;
    ]=];

    -- JMP Instruction Code
    [InstructionKind.JMP] = [=[
        idx = readU(pos + 1, 3, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3, CONST_INSTRUCTION_KEY_4) - 1;
    ]=];

    -- JMPC Instruction Code
    [InstructionKind.JMPC] = [=[
        if(stack[stackl]) then
            idx = readU(pos + 1, 3, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3, CONST_INSTRUCTION_KEY_4) - 1;
        end
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- ADD Instruction Code
    [InstructionKind.ADD] = [=[
        stack[stackl - 1] = stack[stackl - 1] + stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- SUB Instruction Code
    [InstructionKind.SUB] = [=[
        stack[stackl - 1] = stack[stackl - 1] - stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- NEG Instruction Code
    [InstructionKind.NEG] = [=[
        stack[stackl] = -stack[stackl];
    ]=];

    -- CONCAT Instruction Code
    [InstructionKind.CONCAT] = [=[
        stack[stackl - 1] = stack[stackl - 1] .. stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- MUL Instruction Code
    [InstructionKind.MUL] = [=[
        stack[stackl - 1] = stack[stackl - 1] * stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- DIV Instruction Code
    [InstructionKind.DIV] = [=[
        stack[stackl - 1] = stack[stackl - 1] / stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- MOD Instruction Code
    [InstructionKind.MOD] = [=[
        stack[stackl - 1] = stack[stackl - 1] % stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- POW Instruction Code
    [InstructionKind.POW] = [=[
        stack[stackl - 1] = stack[stackl - 1] ^ stack[stackl];
        stack[stackl] = nil;
        stackl = stackl - 1;
    ]=];

    -- LEN Instruction Code
    [InstructionKind.LEN] = [=[
        stack[stackl] = #stack[stackl];
    ]=];

    -- NEWTABLE Instruction Code
    [InstructionKind.NEWTABLE] = [=[
        stackl = stackl + 1;
        stack[stackl] = {};
    ]=];

    -- GETTABLE Instruction Code
    [InstructionKind.GETTABLE] = [=[
        stack[stackl] = stack[stackl - 1][stack[stackl]];
    ]=];

    -- GETTABLE Instruction Code
    [InstructionKind.GETTABLE2] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl][stack[stackl + 1]], nil;
    ]=];

    -- SETTABLE Instruction Code
    [InstructionKind.SETTABLE] = [=[
        stackl = stackl - 2;
        stack[stackl][stack[stackl + 1]] = stack[stackl + 2];
        stack[stackl+1],stack[stackl+2] = nil, nil;
    ]=];

    -- SETTABLE2 Instruction Code
    [InstructionKind.SETTABLE2] = [=[
        stackl = stackl - 1;
        stack[stackl][readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)] = stack[stackl + 1];
        stack[stackl+1] = nil;
    ]=];

    -- SETTABLE3 Instruction Code
    [InstructionKind.SETTABLE3] = [=[
        stackl = stackl - 1;
        tmp = stack[stackl + 1];
        tmp2 = readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3) - 1;
        for i, v in ipairs(tmp) do
            stack[stackl][i + tmp2] = v; 
        end
        
        stack[stackl+1] = nil;
    ]=];

    -- ASSIGNTABLE Instruction Code
    [InstructionKind.ASSIGNTABLE] = [=[
        tmp = bxor(bytes[pos + 3], CONST_INSTRUCTION_KEY_4);
        stack[stackl - tmp][stack[stackl - tmp + 1]] = stack[stackl][readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)];
    ]=];

    -- LOADARGS Instruction Code
    [InstructionKind.LOADARGS] = [=[
        stackl = stackl + 1;
        tmp = readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3);
        if tmp ~= 0 then
            tmp2 = {};
            for i = 1, #args - tmp, 1 do
                tmp2[i] = args[i + tmp];
            end
            stack[stackl] = tmp2;
        else
            stack[stackl] = args;
        end
    ]=];

    -- LOADARG Instruction Code
    [InstructionKind.LOADARG] = [=[
        stackl = stackl + 1;
        stack[stackl] = args[readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)];
    ]=];

    -- SETARGS Instruction Code
    [InstructionKind.SETARGS] = [=[
        stackl = stackl - 1;
        args = stack[stackl + 1];
        stack[stackl + 1] = nil;
    ]=];

    -- RET Instruction Code
    [InstructionKind.RET] = [=[
        return stack[stackl];
    ]=];

    -- RET2 Instruction Code
    [InstructionKind.RET2] = [=[
        return {stack[stackl]};
    ]=];

    -- RET3 Instruction Code
    [InstructionKind.RET3] = [=[
        return {};
    ]=];

    -- DROP Instruction Code
    [InstructionKind.DROP] = [[
        stackl = stackl - 1;
        stack[stackl + 1] = nil;
    ]];

    -- FUNC Instruction Code
    [InstructionKind.FUNC] = [=[
        stackl = stackl + 1;
        stack[stackl] = createBlockFunc(funcPosTable[readU(pos + 1, 3, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3, CONST_INSTRUCTION_KEY_4)], env, locals);
    ]=];

    -- CALL Instruction Code
    [InstructionKind.CALL] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = {stack[stackl](unpack_func(stack[stackl + 1]))}, nil;
    ]=];

    -- CLEARSTACK Instruction Code
    [InstructionKind.CLEARSTACK] = [=[
        stack = {[0] = stack[0]};
        stackl = 0;
    ]=];

    -- PUSHSCOPE Instruction Code
    [InstructionKind.PUSHSCOPE] = [=[
        locals = {[0]=locals};
    ]=];

    -- POPSCOPE Instruction Code
    [InstructionKind.POPSCOPE] = [=[
        locals = locals[0];
    ]=];

    -- UNPACK Instruction Code
    [InstructionKind.UNPACK] = [=[
        tmp, stack[stackl] = stack[stackl], nil;
        for i, v in ipairs(tmp) do
            stack[stackl] = v;
            stackl = stackl + 1;
        end
        stackl = stackl - 1;
    ]=];

    -- PACK Instruction Code
    [InstructionKind.PACK] = [=[
        tmp = {};
        for i, v in ipairs(stack) do
            tmp[i] = v;
        end
        stackl = 1;
        stack = {[0]=stack[0],[1]=tmp};
    ]=];

    -- UNPACKFIRST Instruction Code
    [InstructionKind.UNPACKFIRST] = [=[
        stack[stackl] = stack[stackl][1];
    ]=];

    -- EQ Instruction Code
    [InstructionKind.EQ] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] == stack[stackl+1], nil;
    ]=];

    -- NEQ Instruction Code
    [InstructionKind.NEQ] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] ~= stack[stackl+1], nil;
    ]=];

    -- LT Instruction Code
    [InstructionKind.LT] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] < stack[stackl+1], nil;
    ]=];

    -- GT Instruction Code
    [InstructionKind.GT] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] > stack[stackl+1], nil;
    ]=];

    -- LET Instruction Code
    [InstructionKind.LET] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] <= stack[stackl+1], nil;
    ]=];

    -- GET Instruction Code
    [InstructionKind.GET] = [=[
        stackl = stackl - 1;
        stack[stackl], stack[stackl + 1] = stack[stackl] >= stack[stackl+1], nil;
    ]=];

    -- NOT Instruction Code
    [InstructionKind.NOT] = [=[
        stack[stackl] = not stack[stackl];
    ]=];

    -- SWAP Instruction Code
    [InstructionKind.SWAP] = [=[
        tmp = readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3);
        stack[stackl], stack[stackl - tmp] = stack[stackl - tmp], stack[stackl];
    ]=];

    -- PUSHTEMPSTACK Instruction Code
    [InstructionKind.PUSHTEMPSTACK] = [=[
        stack["l"] = stackl;
        stackl = 0;
        stack = {[0]=stack};
    ]=];

    -- PUSHTEMPSTACK1 Instruction Code
    [InstructionKind.PUSHTEMPSTACK2] = [=[
        stack["l"] = stackl;
        stack = {[0]=stack,[1]=stack[stackl]};
        stackl = 1;
    ]=];

    -- POPTEMPSTACK Instruction Code
    [InstructionKind.POPTEMPSTACK] = [=[
        if stackl > 0 then
            tmp = stack[stackl];
        else
            tmp = nil;
        end
        stack = stack[0];
        stackl = stack["l"] + 1;
        stack[stackl] = tmp;
    ]=];

    -- POPTEMPSTACK2 Instruction Code
    [InstructionKind.POPTEMPSTACK2] = [=[
        stack = stack[0];
        stackl = stack["l"];
    ]=];

    -- FORSKIP Instruction Code
    [InstructionKind.FORSKIP] = [[
        stack[stackl - 2] = stack[stackl - 2] + stack[stackl];
        if stack[stackl] < 0 and stack[stackl - 2] >= stack[stackl - 1] or stack[stackl] > 0 and stack[stackl - 2] <= stack[stackl - 1] then
            idx = idx + 1;
            locals = {[0]=locals, [readU(pos + 1, 2, CONST_INSTRUCTION_KEY_2, CONST_INSTRUCTION_KEY_3)]=stack[stackl - 2]};
        end
    ]];

    -- FORINSKIP Instruction Code
    [InstructionKind.FORINSKIP] = [[
        tmp = stack[stackl];
        tmp2 = {tmp[1](tmp[2], tmp[3])}
        if tmp2[1] ~= nil then
            tmp[3] = tmp2[1];
            stackl = stackl + 1;
            stack[stackl] = tmp2;
            locals = {[0]=locals}
            idx    = idx + 1;
        end
    ]];

    -- FORPREP Instruction Code
    [InstructionKind.FORPREP] = [[
        stack[stackl - 2] = stack[stackl - 2] - stack[stackl];
    ]];

    -- CRASH Instruction Code
    [InstructionKind.CRASH] = [[
        while true do end
    ]];
}

local vars = {
    ["bxorfunc"] = [[
        function(a, b, n, ...)
            local r = 0
            for i = 0, 31 do
                local x = a / 2 + b / 2
                if x ~= floorfunc(x) then
                    r = r + 2^i
                end
                a = floorfunc(a / 2)
                b = floorfunc(b / 2)
            end
            if n then
                return bxorfunc(r, n, ...)
            end
            return r
        end
    ]];
    ["readD"] = [[
        function(j)
            local dbytes = {};
            for i=0,7,1 do
                dbytes[i + 1] = bytes[j + i];
            end
            local sign = 1
            local mantissa = dbytes[2] % 2^4
            for i = 3, 8 do
                mantissa = mantissa * 256 + dbytes[i]
            end
            if dbytes[1] > 127 then sign = -1 end
            local exponent = (dbytes[1] % 128) * 2^4 + floorfunc(dbytes[2] / 2^4)
        
            if exponent == 0 then
                return 0
            end
            mantissa = (ldexpfunc(mantissa, -52) + 1) * sign
            return ldexpfunc(mantissa, exponent - 1023) 
        end
    ]];
    ["readU"] = [[
        function(i, byteLen, ...)
            local codes = {...}
            local val = 0;
            local n = 1;
            for j = 0, byteLen - 1, 1 do
                val = val + bxor(bytes[i + j], codes and codes[j + 1] or 0) * n;
                n = n * 256;
            end
            return val
        end
    ]];
    ["createBlockFunc"] = [[
        function(idx, env, parentScope)
            return function(...)
                return unpack_func(run(idx, {...}, env, parentScope));
            end
        end
    ]];
    ["parseHeaders"] = [[
        function()
            -- Parse Bytecode Header
            -- Read Function Positions
            functionCount = readU(1, 3);
            funcPosTable = {};
            for i = 0, functionCount - 1, 1 do
                funcPosTable[i + 1] = readU(offset + i * 3, 3);
            end
            
            -- Read Constant Positions
            offset = offset + functionCount * 3;
            constantsCount = readU(offset, 3);
            for i = 0, constantsCount - 1, 1 do
                constPosTable[i + 1] = readU(offset + 3 + i * 4, 4);
            end
            offset = offset + constantsCount * 4 + 6;
            
            -- Read Instruction count
            instructionCount = readU(offset - 3, 3);
            constOffset = offset + instructionCount * 4;
        end
    ]];
    ["bxor"] = "nil";
    ["unpack_func"] = [[table and table.unpack or unpack;]];
    ["strchar"]  = [[string.char]];
    ["strbytes"] = [[string.byte]];
    ["strgsub"]  = [[string.gsub]];
    ["strsub"]   = [[string.sub]];
    ["strfind"]  = [[string.find]];
    ["tbremove"] = [[table.remove]];
    ["decodeBytecode"] = [[Error: No Encoding was Provided! This Seems to be an bug in bytecode.lua]];
    ["genv"] = [[getfenv]];
    ["floorfunc"] = [[math.floor]];
    ["constPosTable"] = [[{}]];
    ["ldexpfunc"] = "math.ldexp";
    ["constantsCount"] = "nil";
    ["functionCount"] = "nil";
    ["offset"] = [[4]];
    ["constantTable"] = [[{}]];
    ["funcPosTable"] = [[{}]];
    ["constOffset"] = "nil";
    ["instructionCount"] = "nil";
    ["b32xor"] = "bit32 and bit32.bxor";
    ["bytes"] = [["Error: No Bytecode was Provided! This Seems to be an Bug in bytecode.lua"]];
    ["run"] = [[function() error("The run Function was not Properly Created!") end]];
    ["main"] = [[
        function()
            bxor = b32xor or bxorfunc;
            bytes = decodeBytecode(bytes);
            parseHeaders();
            -- Execute Code
            return createBlockFunc(funcPosTable[1], genv())();
        end
    ]];
};

local vmMain = [[
    return main();
]];

local function generateRunString(opcodes)
    local code = [[
        function(idx, args, env, parentScope)
            local locals = {[0]=parentScope}
            local stack = {};
            local stackl = 0;
            local opcode, pos, d, tmp, tmp2, tmp3;
            pos = offset + (idx - 1) * 4;
            opcode = bxor(bytes[pos], CONST_INSTRUCTION_KEY_1);
            while true do
                d = true;
    ]];

    local insTable = {};
    for ins, opcode in pairs(opcodes) do
        insTable[#insTable+1] = {
            ins = ins,
            opcode = opcode;
        }
    end

    util.shuffle(insTable);
    
    for _, d in ipairs(insTable) do
        local ins, opcode = d.ins, d.opcode;
        code = code .. [[while opcode==]] .. tostring(opcode) .. [[ do ]]
            .. instructions[ins]
        if ins == InstructionKind.RET or ins == InstructionKind.RET2 or ins == InstructionKind.RET3 then
            code = code .. "end\n";
        else
            code = code  .. [[
                idx = idx + 1;
                pos = offset + (idx - 1) * 4;
                opcode = bxor(bytes[pos], CONST_INSTRUCTION_KEY_1)
                d = false;
            end
        ]];
        end
    end

    code = code .. [[
                if d then
                    -- No Operations Where Run This Cycle, Increase Index 
                    idx = idx + 1;
                    pos = offset + (idx - 1) * 4;
                    opcode = bxor(bytes[pos], CONST_INSTRUCTION_KEY_1)
                end
            end
        end
    ]];

    return code;
end

local Encoding = {
	None = "None",
    Base64 = "Base64",
};

local decodingFunctions = {
    [Encoding.None] = [=[function(a)
        local ret = {};
        for i=1, #a, 1 do
            ret[i] = strbytes(a, i);
        end
        return ret;
    end]=],
    [Encoding.Base64] = [=[
        function (data)
            local ret = {};
            data = strgsub(strgsub(data, '.', function(x)
                if (x == '=') then return '' end
                local r,f='',(strfind(encodingConst, x)-1)
                for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                return r;
            end), '%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if (#x ~= 8) then return '' end
                local c=0
                for i=1,8 do c=c+(strsub(x,i,i)=='1' and 2^(8-i) or 0) end
                return strchar(c)
            end);
            for i=1, #data, 1 do
                ret[i] = strbytes(data, i);
            end
            return ret;
        end
    ]=];
}

local vmstrings = {
    instructions = instructions;
    vars = vars;
    vmMain = vmMain;
    generateRunString = generateRunString;
    encoding = Encoding;
    decodingFunctions = decodingFunctions;
}

return vmstrings;
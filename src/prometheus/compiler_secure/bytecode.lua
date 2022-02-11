-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- bytecode.lua
-- This Script contains the Bytecode library for Compiling to Prometheus Bytecode

-- For Lua5.1 Compatibility
local success, bit32 = pcall(require, "bit")
if not success then bit32 = require("prometheus.bit").bit32 end

local logger = require("logger");
local util = require("prometheus.util");
local vmstrings = require("prometheus.compiler_secure.vmstrings");
local Parser = require("prometheus.parser");
local enums = require("prometheus.enums");

local LuaVersion = enums.LuaVersion;
local BIT_MAX_8  = 255;
local BIT_MAX_16 = 65535;

local InstructionKind = require("prometheus.compiler_secure.instructionkind");

local Bytecode = {
	InstructionKind = InstructionKind
};

local tmp_meta = {
	__index = function( _, i ) return i end
}

local Encoding = vmstrings.encoding;

local function getDecodingFunction(encoding)
	return vmstrings.decodingFunctions[encoding] or logger:error(string.format("The Bytecode-Encoding \"%s\" was not found!", encoding));
end

local function encodeBytes(bytes, vmSettings)
	local encoding = vmSettings.encoding;
	-- Encode Bytes using Different Encodings
	if encoding == Encoding.Base64 then
		-- Base64 Implementation
		local b=vmSettings.encodingConst;
		return ((bytes:gsub('.', function(x) 
			local r,b='',x:byte()
			for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
			return r;
		end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
			if (#x < 6) then return '' end
			local c=0
			for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
			return b:sub(c+1,c+1)
		end)..({ '', '==', '=' })[#bytes%3+1])
	end

 	return bytes;
end

local function random_n( n, i, j )
	local result = {}
	local temp = setmetatable( {}, tmp_meta)
	for k = 1, n do
	  -- swap first element in range with randomly selected element in range
	  local idx = math.random( i, j )
	  local v = temp[ idx ]
	  temp[ idx ] = temp[ i ]
	  result[ k ] = v
	  i = i + 1 -- first element in range is fixed from now on
	end
	return result
  end

function Bytecode:generateVmSettings(ir, config)
	config = config or {};

	local temp = {};
	for i = 0, 255 do
		temp[i] = i;
	end
	
	-- Generate Opcodes for Operations
	local opcodes = {};
	for instructionKind, v in pairs(ir.instructionUsed) do
		if v and instructionKind ~= InstructionKind.NOP then
			opcodes[instructionKind] = table.remove(temp, math.random(1, #temp));
		end
	end

	-- Generate 4 8-bit xor-keys to be applied to every instruction
	local instructionKeys = {};
	for i = 1, 4, 1 do
		instructionKeys[i] = math.random(0, 255);
	end

	-- Constant Type Headers
	local consts = random_n(4, 0, 255);

	-- Encoding + Constant for Proper Encoding
	local encoding = config.encoding or Encoding.Base64;
	local encodingConst = nil;

	if encoding == Encoding.Base64 then
		local possibleChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/!,\n\t\a\b\v\"\':;"
		encodingConst = table.concat(util.shuffle(util.chararray(possibleChars)), "", 1, 64);
	end


	return {
		opcodes = opcodes,
		nopopcodes = temp,
		instructionKeys = instructionKeys,
		stringConst = consts[1],
		doubleConst = consts[2],
		n32Const    = consts[3],
		u32Const    = consts[4],
		encoding = encoding,
		encodingConst = encodingConst,
	}
end

function Bytecode:buildInstruction(vmSettings, instructionKind, a, b)
	-- NOP
	if(instructionKind == InstructionKind.NOP) then
		-- NOP has a random opcode that is not occupied by any other instruction
		local ins = {};
		ins[1] = bit32.bxor(vmSettings.nopopcodes[math.random(1, #vmSettings.nopopcodes)], vmSettings.instructionKeys[1]);
		for i = 2, 4, 1 do
			ins[i] = math.random(0, 255);
		end
		return util.bytesToString(ins);
	end

	-- Get Instruction Opcode
	local opcode = vmSettings.opcodes[instructionKind] or logger:error(string.format("Opcode for %s was not declared. This is most likely a bug in bytecode.lua!"));

	-- JUMP and LOADCONST have a single 24 bit argument instead of one 16 bit and an 8 bit
	if(instructionKind == InstructionKind.JMP or instructionKind == InstructionKind.LOADCONST or instructionKind == InstructionKind.FUNC or instructionKind == InstructionKind.JMPC) then
		local aBytes = util.writeU24(a);
		local ins = {};
		-- Opcode
		ins[1] = bit32.bxor(opcode, vmSettings.instructionKeys[1]);
		-- Argument
		ins[2] = bit32.bxor(aBytes[1], vmSettings.instructionKeys[2]);
		ins[3] = bit32.bxor(aBytes[2], vmSettings.instructionKeys[3]);
		ins[4] = bit32.bxor(aBytes[3], vmSettings.instructionKeys[4]);

		return util.bytesToString(ins);
	end

	-- All other instructions
	-- if no arguments supplied they will be set randomly
	local aBytes = util.writeU16(a or math.random(0, BIT_MAX_16));

	local ins = {};
	-- Opcode
	ins[1] = bit32.bxor(opcode, vmSettings.instructionKeys[1]);
	-- Arguments
	ins[2] = bit32.bxor(aBytes[1], vmSettings.instructionKeys[2]);
	ins[3] = bit32.bxor(aBytes[2], vmSettings.instructionKeys[3]);
	ins[4] = bit32.bxor(b or math.random(0, 255), vmSettings.instructionKeys[4]);

	return util.bytesToString(ins);
end

function Bytecode:dumpConst(vmSettings, const)
	if type(const) == "number" then
		if util.isU32(const) then
			return util.bytesToString({vmSettings.u32Const}) .. util.bytesToString(util.writeU32(const));
		elseif util.isU32(-const) then
			return util.bytesToString({vmSettings.n32Const}) .. util.bytesToString(util.writeU32(-const));
		end
		return util.bytesToString({vmSettings.doubleConst}) .. util.bytesToString(util.writeDouble(const));
	end

	if type(const) == "string" then
		return util.bytesToString({
			vmSettings.stringConst,
		}) .. util.bytesToString(util.writeU32(string.len(const))) .. const;
	end
end

function Bytecode:generateBytecode(vmSettings, ir)
	ir:updateInstructionPosInfo();
	local header = "";

	-- Build Instruction Data
	local instructions = "";
	for i, instruction in ipairs(ir.instructions) do
		instructions = instructions .. self:buildInstruction(vmSettings, instruction.kind, instruction.a, instruction.b);
	end

	-- Build Header
	header = header .. util.bytesToString(util.writeU24(#ir.functions));    -- Function Count

	-- Write Functions Header
	for i, node in ipairs(ir.functions) do
		header = header .. util.bytesToString(util.writeU24(node.pos));
	end

	-- Prepare Constant to generate Header
	local constantPositions = {};
	local constants = "";
	local currentConstPos = 0;
	for i, const in ipairs(ir.constants) do
		local bytes = self:dumpConst(vmSettings, const);
		constants = constants .. bytes;
		constantPositions[i] = currentConstPos;
		currentConstPos = currentConstPos + string.len(bytes);
	end

	-- Write constant Count
	header = header .. util.bytesToString(util.writeU24(#ir.constants));

	-- Write Constant Positions to header
	for i, pos in ipairs(constantPositions) do
		header = header .. util.bytesToString(util.writeU32(pos));
	end

 	-- Instruction Count
	header = header .. util.bytesToString(util.writeU24(#ir.instructions));

	return header .. instructions .. constants;
end

local function inlineConstants(code, vmSettings)
	local match = "CONST_[%w%_]+"
	local constTable = {
		["CONST_INSTRUCTION_KEY_1"] = tostring(vmSettings.instructionKeys[1]);
		["CONST_INSTRUCTION_KEY_2"] = tostring(vmSettings.instructionKeys[2]);
		["CONST_INSTRUCTION_KEY_3"] = tostring(vmSettings.instructionKeys[3]);
		["CONST_INSTRUCTION_KEY_4"] = tostring(vmSettings.instructionKeys[4]);
		["CONST_STRING"] = tostring(vmSettings.stringConst);
		["CONST_DOUBLE"] = tostring(vmSettings.doubleConst);
		["CONST_N32"]    = tostring(vmSettings.n32Const);
		["CONST_U32"]    = tostring(vmSettings.u32Const);
	}
	return string.gsub(code, match, constTable);
end

function Bytecode:generateVmCode(vmSettings, bytecode)
	local vars = vmstrings.vars;
	-- Set Bytecode
	vars.decodeBytecode = getDecodingFunction(vmSettings.encoding);
	vars.bytes = "\"" .. util.escape(encodeBytes(bytecode, vmSettings)) .. "\"";
	vars.run   = inlineConstants(vmstrings.generateRunString(vmSettings.opcodes), vmSettings);
	if(vmSettings.encodingConst) then
		vars.encodingConst = "\"" .. util.escape(vmSettings.encodingConst) .. "\"";
	end
	
	local varCodes = {};
	local varNames = {};
	for name, value in pairs(vars) do
		local len = #varNames;
		if len < 1 then len = 1 end;
		table.insert(varNames, name);
		if(value ~= "nil") then
			table.insert(varCodes, {name = name, value = value});
		end
	end

	util.shuffle(varNames);
	util.shuffle(varCodes);

	local code = "local ";
	for i, name in ipairs(varNames) do
		code = code .. name;
		if i < #varNames then
			code = code .. ",";
		else
			code = code .. ";\n"
		end
	end

	for i, val in ipairs(varCodes) do
		code = code .. val.name .. "=" .. inlineConstants(val.value, vmSettings) .. ";\n";
	end

	code = code .. vmstrings.vmMain;

	vars.bytes = nil;
	vars.run   = nil;
	vars.decodeBytecode = nil;
	vars.encodingConst = nil;

	return code;
end

function Bytecode:generateVm(vmSettings, ir)
	local bytecode = Bytecode:generateBytecode(vmSettings, ir);
	local vmCode = Bytecode:generateVmCode(vmSettings, bytecode);
	local parser = Parser:new({
		luaVersion = LuaVersion.Lua51;
	});

	local vmAst = parser:parse(vmCode);
	return vmAst;
end


return Bytecode;

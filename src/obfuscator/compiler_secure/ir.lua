-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- ir.lua
-- This Script contains the IR library for Compiling to Prometheus Bytecode

local logger = require("logger");
local util = require("obfuscator.util");

local Bytecode = require("obfuscator.compiler_secure.bytecode");
local InstructionKind = Bytecode.InstructionKind

local function Instruction(tb)
	tb.pos = -1;
	tb.toString = tb.toString or function(self)
		local ret = self.kind;
		if(self.a) then
			if(self.b) then
				ret = string.format("%s %d, %d", self.kind, self.a, self.b)
			else
				ret = string.format("%s %d", self.kind, self.a)
			end
		end
		return ret .. (self.comment and (" ;" .. self.command) or "");
	end
	return tb;
end

local IR = {
	InstructionKind = InstructionKind,
};


function IR:new()
	local ir = {
		functions       = {},
		instructions    = {},
		constants       = {},
		constantsLookup = {},
		instructionUsed = {},
	}
	
	setmetatable(ir, self);
	self.__index = self;
	
	return ir;
end

function IR:pushInstruction(instruction, pos)
	self.instructionUsed[instruction.kind] = true;
	if pos then
		table.insert(self.instructions, pos, instruction);
	else
		table.insert(self.instructions, instruction);
	end
	return #self.instructions
end
IR.instruction = IR.pushInstruction

function IR:createFunction(ins)
	local id = #self.functions + 1;
	table.insert(self.functions, ins);
	return id;
end

function IR:instructionIsUsed(kind)
	return self.instructionUsed[kind] == true;
end

function IR:getCurrentPos()
	return #self.instructions
end

function IR:toString()
	self:updateInstructionPosInfo();
	local str = ".func\n";
	
	for i, funcInstruction in ipairs(self.functions) do
		str = str .. string.format("%4d:  %d\n", i, funcInstruction.pos);
	end
	
	str = str .. ".code\n";
	
	for i, ins in ipairs(self.instructions) do
		str = str .. string.format("%4d:  %s\n", ins.pos, ins:toString());
	end
	
	str = str .. ".const\n";
	
	for id, const in ipairs(self.constants) do
		if type(const) == "string" then
			str = str .. string.format("%4d:  \"%s\"\n", id, util.escape(const)); 
		else
			str = str .. string.format("%4d:  %d\n", id, const);
		end
	end
	
	return str;
end

function IR:updateInstructionPosInfo()
	for i, ins in ipairs(self.instructions) do
		ins.pos = i;
	end

	for i, ins in ipairs(self.instructions) do
		if(ins.kind == InstructionKind.JMP or ins.kind == InstructionKind.JMPC) then
			ins.a = ins.to.pos;
		end
	end
end

function IR:constant(value)
	if type(value) == "string" or type(value) == "number" then
		if self.constantsLookup[value] then
			return self.constantsLookup[value]
		end
		
		table.insert(self.constants, value)
		local id = #self.constants;
		self.constantsLookup[value] = id;
		return id;
	else
		logger:error("IR Constants must be Strings or Numbers. This is Probably a bug in the Compiler!")
	end
end

function IR:optimize()
	self:stripNopsAndAddJumpInfo();
	self:stripDeadInstructions();
	self:updateUsedInstructions();
end

function IR:updateUsedInstructions()
	self.instructionUsed = {};
	for i, instruction in ipairs(self.instructions) do
		self.instructionUsed[instruction.kind] = true;
	end
end

-- Removes dead Instructions After Jump
function IR:stripDeadInstructions()
	local insc = {};
	local isDead = false;
	local skip = false;
	for i, instruction in ipairs(self.instructions) do
		if(instruction.isJumpedTo) then
			isDead = false;
		end

		if(not isDead) then
			insc[#insc + 1] = instruction;
		end

		if skip then
			skip = false
		else
			if(instruction.kind == InstructionKind.FORSKIP or instruction.kind == InstructionKind.FORINSKIP) then
				skip = true;
			elseif(instruction.kind == InstructionKind.JMP) then
				isDead = true;
			elseif(instruction.kind == InstructionKind.RET) then
				isDead = true;
			elseif(instruction.kind == InstructionKind.RET2) then
				isDead = true;
			elseif(instruction.kind == InstructionKind.RET3) then
				isDead = true;
			end
		end
	end

	self.instructions = insc;
end

-- Sets Jumpmarks away from Nops and also sets the isJumpedTo flag
function IR:setJumpmarksToNextInstruction()
	self:updateInstructionPosInfo();
	for i, ins in ipairs(self.functions) do
		ins.isJumpedTo = true;
	end
	for i, instruction in ipairs(self.instructions) do
		if(instruction.kind == InstructionKind.JMP or instruction.kind == InstructionKind.JMPC) then
			local to = instruction.to;
			while to.kind == InstructionKind.NOP do
				to = self.instructions[to.pos + 1];
			end
			instruction.to = to;
			to.isJumpedTo = true;
			to.jumpedToFrom = to.jumpedToFrom or {};
			table.insert(to.jumpedToFrom, instruction);
		end
	end
end

-- Removes all Nop Instructions
function IR:stripNopsAndAddJumpInfo()
	self:setJumpmarksToNextInstruction();
	local insc = {};
	for i, instruction in ipairs(self.instructions) do
		if(instruction.kind ~= InstructionKind.NOP or instruction.isJumpedTo) then
			insc[#insc + 1] = instruction;
		end
	end
	self.instructions = insc;
end

function IR:UNPACK()
	return Instruction{
		kind = InstructionKind.UNPACK,
	}
end

function IR:PACK()
	return Instruction{
		kind = InstructionKind.PACK,
	}
end

function IR:UNPACKFIRST()
	return Instruction{
		kind = InstructionKind.UNPACKFIRST,
	}
end

function IR:PUSHSCOPE()
	return Instruction{
		kind = InstructionKind.PUSHSCOPE,
	}
end

function IR:POPSCOPE()
	return Instruction{
		kind = InstructionKind.POPSCOPE,
	}
end

function IR:EQ()
	return Instruction{
		kind = InstructionKind.EQ,
	}
end

function IR:NEQ()
	return Instruction{
		kind = InstructionKind.NEQ,
	}
end

function IR:LT()
	return Instruction{
		kind = InstructionKind.LT,
	}
end

function IR:LET()
	return Instruction{
		kind = InstructionKind.LET,
	}
end

function IR:DUP()
	return Instruction{
		kind = InstructionKind.DUP,
	}
end

function IR:PUSHTEMPSTACK()
	return Instruction{
		kind = InstructionKind.PUSHTEMPSTACK,
	}
end

function IR:PUSHTEMPSTACK2()
	return Instruction{
		kind = InstructionKind.PUSHTEMPSTACK2,
	}
end

function IR:SWAP(offset)
	offset = offset or 1;
	return Instruction{
		kind = InstructionKind.SWAP,
		a = offset,
	}
end

function IR:POPTEMPSTACK()
	return Instruction{
		kind = InstructionKind.POPTEMPSTACK,
	}
end

function IR:POPTEMPSTACK2()
	return Instruction{
		kind = InstructionKind.POPTEMPSTACK2,
	}
end

function IR:GT()
	return Instruction{
		kind = InstructionKind.GT,
	}
end

function IR:GET()
	return Instruction{
		kind = InstructionKind.GET,
	}
end

function IR:NOT()
	return Instruction{
		kind = InstructionKind.NOT,
	}
end

function IR:LOADCONST(id)
	return Instruction{
		kind = InstructionKind.LOADCONST,
		a  = id,
	}
end

function IR:FORPREP()
	return Instruction{
		kind = InstructionKind.FORPREP,
	}
end

function IR:FORSKIP(varid)
	return Instruction{
		kind = InstructionKind.FORSKIP,
		a = varid,
	}
end

function IR:FORINSKIP()
	return Instruction{
		kind = InstructionKind.FORINSKIP,
	}
end

function IR:GETGLOBAL()
	return Instruction{
		kind = InstructionKind.GETGLOBAL,
	}
end

function IR:SETGLOBAL()
	return Instruction{
		kind = InstructionKind.SETGLOBAL,
	}
end

function IR:POPTABLESTART()
	return Instruction{
		kind = InstructionKind.POPTABLESTART,
	}
end

function IR:ASSIGNGLOBAL(n)
	return Instruction{
		kind = InstructionKind.ASSIGNGLOBAL,
		a = n,
	}
end

function IR:GETLOCAL(id, scopeShift)
	return Instruction{
		kind = InstructionKind.GETLOCAL,
		a = id,
		b = scopeShift,
	}
end

function IR:CRASH()
	return Instruction{
		kind = InstructionKind.CRASH,
	}
end

function IR:SETLOCAL(id, scopeShift)
	return Instruction{
		kind = InstructionKind.SETLOCAL,
		a = id,
		b = scopeShift,
	}
end

function IR:ASSIGNLOCAL(id, scopeShift)
	return Instruction{
		kind = InstructionKind.ASSIGNLOCAL,
		a = id,
		b = scopeShift,
	}
end

function IR:LOADNIL()
	return Instruction{
		kind = InstructionKind.LOADNIL,
	}
end

function IR:LOADTRUE()
	return Instruction{
		kind = InstructionKind.LOADTRUE,
	}
end

function IR:LOADFALSE()
	return Instruction{
		kind = InstructionKind.LOADFALSE,
	}
end

function IR:JMP(to)
	return Instruction{
		kind = InstructionKind.JMP,
		to = to,
	}
end

function IR:JMPC(to)
	return Instruction{
		kind = InstructionKind.JMPC,
		to = to,
	}
end

function IR:CLEARSTACK()
	return Instruction{
		kind = InstructionKind.CLEARSTACK,
	}
end

function IR:ADD()
	return Instruction{
		kind = InstructionKind.ADD,
	}
end

function IR:SUB()
	return Instruction{
		kind = InstructionKind.SUB,
	}
end

function IR:NEG()
	return Instruction{
		kind = InstructionKind.NEG,
	}
end

function IR:CONCAT()
	return Instruction{
		kind = InstructionKind.CONCAT,
	}
end

function IR:MUL()
	return Instruction{
		kind = InstructionKind.MUL,
	}
end

function IR:DIV()
	return Instruction{
		kind = InstructionKind.DIV,
	}
end

function IR:MOD()
	return Instruction{
		kind = InstructionKind.MOD,
	}
end

function IR:POW()
	return Instruction{
		kind = InstructionKind.POW,
	}
end

function IR:LEN()
	return Instruction{
		kind = InstructionKind.LEN,
	}
end

function IR:NEWTABLE()
	return Instruction{
		kind = InstructionKind.NEWTABLE,
	}
end

function IR:GETTABLE()
	return Instruction{
		kind = InstructionKind.GETTABLE,
	}
end

function IR:GETTABLE2()
	return Instruction{
		kind = InstructionKind.GETTABLE2,
	}
end

function IR:SETTABLE()
	return Instruction{
		kind = InstructionKind.SETTABLE,
	}
end

-- Sets the table at the given index
function IR:SETTABLE2(idx)
	return Instruction{
		kind = InstructionKind.SETTABLE2,
		a    = idx,
	}
end

-- Takes an Array and pushes that to the table at the given index
function IR:SETTABLE3(idx)
	return Instruction{
		kind = InstructionKind.SETTABLE3,
		a    = idx,
	}
end

function IR:ASSIGNTABLE(i, offset) 
	return Instruction{
		kind = InstructionKind.ASSIGNTABLE,
		a    = i,
		b    = offset,
	}
end

function IR:LOADARGS(start)
	return Instruction{
		kind = InstructionKind.LOADARGS,
		a = start or 0;
	}
end

function IR:LOADARG(n)
	return Instruction{
		kind = InstructionKind.LOADARG,
		a    = n,
	}
end

function IR:SETARGS()
	return Instruction{
		kind = InstructionKind.SETARGS,
	}
end

function IR:RET()
	return Instruction{
		kind = InstructionKind.RET,
	}
end

function IR:RET2()
	return Instruction{
		kind = InstructionKind.RET2,
	}
end

function IR:RET3()
	return Instruction{
		kind = InstructionKind.RET3,
	}
end

function IR:DROP()
	return Instruction{
		kind = InstructionKind.DROP,
	}
end

function IR:FUNC(id)
	return Instruction{
		kind = InstructionKind.FUNC,
		a = id,
	}
end

function IR:CALL()
	return Instruction{
		kind = InstructionKind.CALL,
	}
end

function IR:NOP()
	return Instruction{
		kind = InstructionKind.NOP,
	}
end

return IR;
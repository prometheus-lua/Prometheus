-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- ast.lua
--
-- This Script provides the Abstract Syntax Tree (AST) for Prometheus.

local Ast = {}

local AstKind = {
	-- Misc
	TopNode = "TopNode";
	Block = "Block";

	-- Statements
	ContinueStatement = "ContinueStatement";
	BreakStatement = "BreakStatement";
	DoStatement = "DoStatement";
	WhileStatement = "WhileStatement";
	ReturnStatement = "ReturnStatement";
	RepeatStatement = "RepeatStatement";
	ForInStatement = "ForInStatement";
	ForStatement = "ForStatement";
	IfStatement = "IfStatement";
	FunctionDeclaration = "FunctionDeclaration";
	LocalFunctionDeclaration = "LocalFunctionDeclaration";
	LocalVariableDeclaration = "LocalVariableDeclaration";
	FunctionCallStatement = "FunctionCallStatement";
	PassSelfFunctionCallStatement = "PassSelfFunctionCallStatement";
	AssignmentStatement = "AssignmentStatement";

	-- LuaU Compound Statements
	CompoundAddStatement = "CompoundAddStatement";
	CompoundSubStatement = "CompoundSubStatement";
	CompoundMulStatement = "CompoundMulStatement";
	CompoundDivStatement = "CompoundDivStatement";
	CompoundFloorDivStatement = "CompoundFloorDivStatement";
	CompoundModStatement = "CompoundModStatement";
	CompoundPowStatement = "CompoundPowStatement";
	CompoundConcatStatement = "CompoundConcatStatement";

	-- Assignment Index
	AssignmentIndexing = "AssignmentIndexing";
	AssignmentVariable = "AssignmentVariable";

	-- Expression Nodes
	BooleanExpression = "BooleanExpression";
	NumberExpression = "NumberExpression";
	IntegerExpression = "IntegerExpression";
	StringExpression = "StringExpression";
	NilExpression = "NilExpression";
	VarargExpression = "VarargExpression";
	OrExpression = "OrExpression";
	AndExpression = "AndExpression";
	LessThanExpression = "LessThanExpression";
	GreaterThanExpression = "GreaterThanExpression";
	LessThanOrEqualsExpression = "LessThanOrEqualsExpression";
	GreaterThanOrEqualsExpression = "GreaterThanOrEqualsExpression";
	NotEqualsExpression = "NotEqualsExpression";
	EqualsExpression = "EqualsExpression";
	StrCatExpression = "StrCatExpression";
	AddExpression = "AddExpression";
	SubExpression = "SubExpression";
	MulExpression = "MulExpression";
	DivExpression = "DivExpression";
	FloorDivExpression = "FloorDivExpression";
	ModExpression = "ModExpression";
	NotExpression = "NotExpression";
	LenExpression = "LenExpression";
	NegateExpression = "NegateExpression";
	PowExpression = "PowExpression";
	IndexExpression = "IndexExpression";
	FunctionCallExpression = "FunctionCallExpression";
	PassSelfFunctionCallExpression = "PassSelfFunctionCallExpression";
	VariableExpression = "VariableExpression";
	FunctionLiteralExpression = "FunctionLiteralExpression";
	TableConstructorExpression = "TableConstructorExpression";

	-- Table Entry
	TableEntry = "TableEntry";
	KeyedTableEntry = "KeyedTableEntry";

	-- Misc
	NopStatement = "NopStatement";

	IfElseExpression = "IfElseExpression";
}

local astKindExpressionLookup = {
	[AstKind.BooleanExpression] = 0;
	[AstKind.NumberExpression] = 0;
	[AstKind.IntegerExpression] = 0;
	[AstKind.StringExpression] = 0;
	[AstKind.NilExpression] = 0;
	[AstKind.VarargExpression] = 0;
	[AstKind.OrExpression] = 12;
	[AstKind.AndExpression] = 11;
	[AstKind.LessThanExpression] = 10;
	[AstKind.GreaterThanExpression] = 10;
	[AstKind.LessThanOrEqualsExpression] = 10;
	[AstKind.GreaterThanOrEqualsExpression] = 10;
	[AstKind.NotEqualsExpression] = 10;
	[AstKind.EqualsExpression] = 10;
	[AstKind.StrCatExpression] = 9;
	[AstKind.AddExpression] = 8;
	[AstKind.SubExpression] = 8;
	[AstKind.MulExpression] = 7;
	[AstKind.DivExpression] = 7;
	[AstKind.FloorDivExpression] = 7;
	[AstKind.ModExpression] = 7;
	[AstKind.NotExpression] = 5;
	[AstKind.LenExpression] = 5;
	[AstKind.NegateExpression] = 5;
	[AstKind.PowExpression] = 4;
	[AstKind.IndexExpression] = 1;
	[AstKind.AssignmentIndexing] = 1;
	[AstKind.FunctionCallExpression] = 2;
	[AstKind.PassSelfFunctionCallExpression] = 2;
	[AstKind.VariableExpression] = 0;
	[AstKind.AssignmentVariable] = 0;
	[AstKind.FunctionLiteralExpression] = 3;
	[AstKind.TableConstructorExpression] = 3;
}

Ast.AstKind = AstKind;

function Ast.astKindExpressionToNumber(kind)
	return astKindExpressionLookup[kind] or 100;
end

function Ast.ConstantNode(val)
	if type(val) == "nil" then
		return Ast.NilExpression();
	end

	if type(val) == "string" then
		return Ast.StringExpression(val);
	end

	if type(val) == "number" then
		return Ast.NumberExpression(val);
	end

	if type(val) == "boolean" then
		return Ast.BooleanExpression(val);
	end
end



function Ast.NopStatement()
	return {
		kind = AstKind.NopStatement;
	}
end

function Ast.IfElseExpression(condition, true_value, elseifs, false_value)
	return {
		kind = AstKind.IfElseExpression,
		condition = condition,
		true_value = true_value,
		elseifs = elseifs,
		false_value = false_value
	}
end

-- Create Ast Top Node
function Ast.TopNode(body, globalScope)
	return {
		kind = AstKind.TopNode,
		body = body,
		globalScope = globalScope,

	}
end

function Ast.TableEntry(value)
	return {
		kind = AstKind.TableEntry,
		value = value,

	}
end

function Ast.KeyedTableEntry(key, value)
	return {
		kind = AstKind.KeyedTableEntry,
		key = key,
		value = value,

	}
end

function Ast.TableConstructorExpression(entries)
	return {
		kind = AstKind.TableConstructorExpression,
		entries = entries,
	};
end

-- Create Statement Block
function Ast.Block(statements, scope)
	return {
		kind = AstKind.Block,
		statements = statements,
		scope = scope,
	}
end

-- Create Break Statement
function Ast.BreakStatement(loop, scope)
	return {
		kind = AstKind.BreakStatement,
		loop = loop,
		scope = scope,
	}
end

-- Create Continue Statement
function Ast.ContinueStatement(loop, scope)
	return {
		kind = AstKind.ContinueStatement,
		loop = loop,
		scope = scope,
	}
end

function Ast.PassSelfFunctionCallStatement(base, passSelfFunctionName, args)
	return {
		kind = AstKind.PassSelfFunctionCallStatement,
		base = base,
		passSelfFunctionName = passSelfFunctionName,
		args = args,
	}
end

function Ast.AssignmentStatement(lhs, rhs)
	if(#lhs < 1) then
		print(debug.traceback());
		error("Something went wrong!");
	end
	return {
		kind = AstKind.AssignmentStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundAddStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundAddStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundSubStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundSubStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundMulStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundMulStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundDivStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundDivStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundFloorDivStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundFloorDivStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundPowStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundPowStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundModStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundModStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.CompoundConcatStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundConcatStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

function Ast.FunctionCallStatement(base, args)
	return {
		kind = AstKind.FunctionCallStatement,
		base = base,
		args = args,
	}
end

function Ast.ReturnStatement(args)
	return {
		kind = AstKind.ReturnStatement,
		args = args,
	}
end

function Ast.DoStatement(body)
	return {
		kind = AstKind.DoStatement,
		body = body,
	}
end

function Ast.WhileStatement(body, condition, parentScope)
	return {
		kind = AstKind.WhileStatement,
		body = body,
		condition = condition,
		parentScope = parentScope,
	}
end

function Ast.ForInStatement(scope, vars, expressions, body, parentScope)
	return {
		kind = AstKind.ForInStatement,
		scope = scope,
		ids = vars,
		vars = vars,
		expressions = expressions,
		body = body,
		parentScope = parentScope,
	}
end

function Ast.ForStatement(scope, id, initialValue, finalValue, incrementBy, body, parentScope)
	return {
		kind = AstKind.ForStatement,
		scope = scope,
		id = id,
		initialValue = initialValue,
		finalValue = finalValue,
		incrementBy = incrementBy,
		body = body,
		parentScope = parentScope,
	}
end

function Ast.RepeatStatement(condition, body, parentScope)
	return {
		kind = AstKind.RepeatStatement,
		body = body,
		condition = condition,
		parentScope = parentScope,
	}
end

function Ast.IfStatement(condition, body, elseifs, elsebody)
	return {
		kind = AstKind.IfStatement,
		condition = condition,
		body = body,
		elseifs = elseifs,
		elsebody = elsebody,
	}
end

function Ast.FunctionDeclaration(scope, id, indices, args, body)
	return {
		kind = AstKind.FunctionDeclaration,
		scope = scope,
		baseScope = scope,
		id = id,
		baseId = id,
		indices = indices,
		args = args,
		body = body,
		getName = function(self)
			return self.scope:getVariableName(self.id);
		end,
	}
end

function Ast.LocalFunctionDeclaration(scope, id, args, body)
	return {
		kind = AstKind.LocalFunctionDeclaration,
		scope = scope,
		id = id,
		args = args,
		body = body,
		getName = function(self)
			return self.scope:getVariableName(self.id);
		end,
	}
end

function Ast.LocalVariableDeclaration(scope, ids, expressions)
	return {
		kind = AstKind.LocalVariableDeclaration,
		scope = scope,
		ids = ids,
		expressions = expressions,
	}
end

function Ast.IntegerExpression(source)
	return {kind = AstKind.IntegerExpression, value = source, isConstant = false};
end

function Ast.VarargExpression()
	return {
		kind = AstKind.VarargExpression;
		isConstant = false,
	}
end

function Ast.BooleanExpression(value)
	return {
		kind = AstKind.BooleanExpression,
		isConstant = true,
		value = value,
	}
end

function Ast.NilExpression()
	return {
		kind = AstKind.NilExpression,
		isConstant = true,
		value = nil,
	}
end

function Ast.NumberExpression(value)
	return {
		kind = AstKind.NumberExpression,
		isConstant = true,
		value = value,
	}
end

function Ast.StringExpression(value)
	return {
		kind = AstKind.StringExpression,
		isConstant = true,
		value = value,
	}
end

function Ast.OrExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value or rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.OrExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.AndExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value and rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.AndExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.LessThanExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value < rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LessThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.GreaterThanExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value > rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.GreaterThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.LessThanOrEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value <= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LessThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.GreaterThanOrEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value >= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.GreaterThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.NotEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value ~= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NotEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.EqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value == rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.EqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.StrCatExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value .. rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.StrCatExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.AddExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value + rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.AddExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.SubExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value - rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.SubExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.MulExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value * rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.MulExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.DivExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant and rhs.value ~= 0) then
		local success, val = pcall(function() return lhs.value / rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.DivExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.FloorDivExpression(lhs, rhs, simplify)
	if simplify and lhs.isConstant and rhs.isConstant
		and type(lhs.value) == "number" and type(rhs.value) == "number" and rhs.value ~= 0 then
		return Ast.NumberExpression(math.floor(lhs.value / rhs.value));
	end
	return {
		kind = AstKind.FloorDivExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.ModExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value % rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.ModExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.NotExpression(rhs, simplify)
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return not rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NotExpression,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.NegateExpression(rhs, simplify)
	if simplify and rhs.kind == AstKind.IntegerExpression then
		local source = rhs.value;
		if source:sub(1, 1) == "-" then return Ast.IntegerExpression(source:sub(2)) end
		local prefix = source:sub(1, 2):lower();
		if prefix ~= "0x" and prefix ~= "0b" then return Ast.IntegerExpression("-" .. source) end
		local digits = source:sub(3, -2):lower();
		if prefix == "0b" then
			digits = string.rep("0", (4 - #digits % 4) % 4) .. digits;
			local hex = {};
			for i = 1, #digits, 4 do hex[#hex + 1] = string.format("%x", tonumber(digits:sub(i, i + 3), 2)) end
			digits = table.concat(hex);
		end
		digits = digits:gsub("^0+", "");
		digits = string.rep("0", 16 - #digits) .. digits;
		local hex, carry = {}, 1;
		for i = 16, 1, -1 do
			local value = 15 - tonumber(digits:sub(i, i), 16) + carry;
			hex[i] = string.format("%x", value % 16);
			carry = math.floor(value / 16);
		end
		return Ast.IntegerExpression("0x" .. table.concat(hex) .. "i");
	end
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return -rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NegateExpression,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.LenExpression(rhs, simplify)
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return #rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LenExpression,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.PowExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value ^ rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.PowExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

function Ast.IndexExpression(base, index)
	return {
		kind = AstKind.IndexExpression,
		base = base,
		index = index,
		isConstant = false,
	}
end

function Ast.AssignmentIndexing(base, index)
	return {
		kind = AstKind.AssignmentIndexing,
		base = base,
		index = index,
		isConstant = false,
	}
end

function Ast.PassSelfFunctionCallExpression(base, passSelfFunctionName, args)
	return {
		kind = AstKind.PassSelfFunctionCallExpression,
		base = base,
		passSelfFunctionName = passSelfFunctionName,
		args = args,

	}
end

function Ast.FunctionCallExpression(base, args)
	return {
		kind = AstKind.FunctionCallExpression,
		base = base,
		args = args,
	}
end

function Ast.VariableExpression(scope, id)
	scope:addReference(id);
	return {
		kind = AstKind.VariableExpression,
		scope = scope,
		id = id,
		getName = function(self)
			return self.scope.getVariableName(self.id);
		end,
	}
end

function Ast.AssignmentVariable(scope, id)
	scope:addReference(id);
	return {
		kind = AstKind.AssignmentVariable,
		scope = scope,
		id = id,
		getName = function(self)
			return self.scope.getVariableName(self.id);
		end,
	}
end

function Ast.FunctionLiteralExpression(args, body)
	return {
		kind = AstKind.FunctionLiteralExpression,
		args = args,
		body = body,
	}
end



return Ast;

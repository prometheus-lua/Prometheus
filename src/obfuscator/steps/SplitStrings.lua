-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- SplitStrings.lua
--
-- This Script provides a Simple Obfuscation Step for splitting Strings

local Step = require("obfuscator.step");
local Ast = require("obfuscator.ast");
local visitAst = require("obfuscator.visitast");
local Parser = require("obfuscator.parser");
local util = require("obfuscator.util");
local enums = require("obfuscator.enums")

local LuaVersion = enums.LuaVersion;

local SplitStrings = Step:extend();
SplitStrings.Description = "This Step splits Strings to a specific or random length";
SplitStrings.Name = "Split Strings";

SplitStrings.SettingsDescriptor = {
	Treshold = {
		name = "Treshold",
		description = "The relative amount of nodes that will be affected",
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	MinLength = {
		name = "MinLength",
		description = "The minimal length for the chunks in that the Strings are splitted",
		type = "number",
		default = 5,
		min = 1,
		max = nil,
	},
	MaxLength = {
		name = "MaxLength",
		description = "The maximal length for the chunks in that the Strings are splitted",
		type = "number",
		default = 5,
		min = 1,
		max = nil,
	},
	ConcatenationType = {
		name = "ConcatenationType",
		description = "The Functions used for Concatenation. Note that when using coustom, the String Array will also be Shuffled",
		type = "enum",
		values = {
			"strcat",
			"table",
			"coustom",
		},
		default = "coustom",
	},
	CoustomFunctionType = {
		name = "CoustomFunctionType",
		description = "The Type of Function code injection This Option only applies when coustom Concatenation is selected.\
Note that when chosing inline, the code size may increase significantly!",
		type = "enum",
		values = {
			"global",
			"local",
			"inline",
		},
		default = "global",
	},
	CoustomLocalFunctionsCount = {
		name = "CoustomLocalFunctionsCount",
		description = "The number of local functions per scope. This option only applies when CoustomFunctionType = local",
		type = "number",
		default = 2,
		min = 1,
	}
}

function SplitStrings:init(settings) end

local function generateTableConcatNode(chunks, data)
	local chunkNodes = {};
	for i, chunk in ipairs(chunks) do
		table.insert(chunkNodes, Ast.TableEntry(Ast.StringExpression(chunk)));
	end
	local tb = Ast.TableConstructorExpression(chunkNodes);
	return Ast.FunctionCallExpression(Ast.VariableExpression(data.tableConcatScope, data.tableConcatId), {tb});	
end

local function generateStrCatNode(chunks)
	-- Put Together Expression for Concatenating String
	local generatedNode = nil;
	for i, chunk in ipairs(chunks) do
		if generatedNode then
			generatedNode = Ast.StrCatExpression(generatedNode, Ast.StringExpression(chunk));
		else
			generatedNode = Ast.StringExpression(chunk);
		end
	end
	return generatedNode
end

local coustomVariants = 2;
local coustom1Code = [=[
function coustom(table)
    local stringTable, str = table[#table], "";
    for i=1,#stringTable, 1 do
        str = str .. stringTable[table[i]];
	end
	return str
end
]=];

local coustom2Code = [=[
function coustom(tb)
	local str = "";
	for i=1, #tb / 2, 1 do
		str = str .. tb[#tb / 2 + tb[i]];
	end
	return str
end
]=];

local function generateCoustomNodeArgs(chunks, data, variant)
	local shuffled = {};
	local shuffledIndices = {};
	for i = 1, #chunks, 1 do
		shuffledIndices[i] = i;
	end
	util.shuffle(shuffledIndices);
	
	for i, v in ipairs(shuffledIndices) do
		shuffled[v] = chunks[i];
	end
	
	-- Coustom Function Type 1
	if variant == 1 then
		local args = {};
		local tbNodes = {};
		
		for i, v in ipairs(shuffledIndices) do
			table.insert(args, Ast.TableEntry(Ast.NumberExpression(v)));
		end
		
		for i, chunk in ipairs(shuffled) do
			table.insert(tbNodes, Ast.TableEntry(Ast.StringExpression(chunk)));
		end
		
		local tb = Ast.TableConstructorExpression(tbNodes);
		
		table.insert(args, Ast.TableEntry(tb));
		return {Ast.TableConstructorExpression(args)};
		
	-- Coustom Function Type 2
	else
		
		local args = {};
		for i, v in ipairs(shuffledIndices) do
			table.insert(args, Ast.TableEntry(Ast.NumberExpression(v)));
		end
		for i, chunk in ipairs(shuffled) do
			table.insert(args, Ast.TableEntry(Ast.StringExpression(chunk)));
		end
		return {Ast.TableConstructorExpression(args)};
	end
	
end

local function generateCoustomFunctionLiteral(parentScope, variant)
	local parser = Parser:new({
		LuaVersion = LuaVersion.Lua52;
	});

	-- Coustom Function Type 1
	if variant == 1 then
		local funcDeclNode = parser:parse(coustom1Code).body.statements[1];
		local funcBody = funcDeclNode.body;
		local funcArgs = funcDeclNode.args;
		funcBody.scope:setParent(parentScope);
		return Ast.FunctionLiteralExpression(funcArgs, funcBody);
		
		-- Coustom Function Type 2
	else
		local funcDeclNode = parser:parse(coustom2Code).body.statements[1];
		local funcBody = funcDeclNode.body;
		local funcArgs = funcDeclNode.args;
		funcBody.scope:setParent(parentScope);
		return Ast.FunctionLiteralExpression(funcArgs, funcBody);
	end
end

local function generateGlobalCoustomFunctionDeclaration(ast, data)
	local parser = Parser:new({
		LuaVersion = LuaVersion.Lua52;
	});
	
	-- Coustom Function Type 1
	if data.coustomFunctionVariant == 1 then
		local astScope = ast.body.scope;
		local funcDeclNode = parser:parse(coustom1Code).body.statements[1];
		local funcBody = funcDeclNode.body;
		local funcArgs = funcDeclNode.args;
		funcBody.scope:setParent(astScope);
		return Ast.LocalVariableDeclaration(astScope, {data.coustomFuncId},
		{Ast.FunctionLiteralExpression(funcArgs, funcBody)});
	-- Coustom Function Type 2
	else
		local astScope = ast.body.scope;
		local funcDeclNode = parser:parse(coustom2Code).body.statements[1];
		local funcBody = funcDeclNode.body;
		local funcArgs = funcDeclNode.args;
		funcBody.scope:setParent(astScope);
		return Ast.LocalVariableDeclaration(data.coustomFuncScope, {data.coustomFuncId},
		{Ast.FunctionLiteralExpression(funcArgs, funcBody)});
	end
end

function SplitStrings:variant()
	return math.random(1, coustomVariants);
end

function SplitStrings:apply(ast, pipeline)
	local data = {};
	
	
	if(self.ConcatenationType == "table") then
		local scope = ast.body.scope;
		local id = scope:addVariable();
		data.tableConcatScope = scope;
		data.tableConcatId = id;
	elseif(self.ConcatenationType == "coustom") then
		data.coustomFunctionType = self.CoustomFunctionType;
		if data.coustomFunctionType == "global" then
			local scope = ast.body.scope;
			local id = scope:addVariable();
			data.coustomFuncScope = scope;
			data.coustomFuncId = id;
			data.coustomFunctionVariant = self:variant();
		end
	end
	
	
	local coustomLocalFunctionsCount = self.CoustomLocalFunctionsCount;
	local self2 = self;
	
	visitAst(ast, function(node, data) 
		-- Previsit Function
		
		-- Create Local Function declarations
		if(self.ConcatenationType == "coustom" and data.coustomFunctionType == "local" and node.kind == Ast.AstKind.Block and node.isFunctionBlock) then
			data.functionData.localFunctions = {};
			for i = 1, coustomLocalFunctionsCount, 1 do
				local scope = data.scope;
				local id = scope:addVariable();
				local variant = self:variant();
				table.insert(data.functionData.localFunctions, {
					scope = scope,
					id = id,
					variant = variant,
					used = false,
				});
			end
		end
		
	end, function(node, data)
		-- PostVisit Function
		
		-- Create actual function literals for local coustomFunctionType
		if(self.ConcatenationType == "coustom" and data.coustomFunctionType == "local" and node.kind == Ast.AstKind.Block and node.isFunctionBlock) then
			for i, func in ipairs(data.functionData.localFunctions) do
				if func.used then
					local literal = generateCoustomFunctionLiteral(func.scope, func.variant);
					table.insert(node.statements, 1, Ast.LocalVariableDeclaration(func.scope, {func.id}, {literal}));
				end
			end
		end
		
		
		-- Apply Only to String nodes
		if(node.kind == Ast.AstKind.StringExpression) then
			local str = node.value;
			local chunks = {};
			local i = 1;
			
			-- Split String into Parts of length between MinLength and MaxLength
			while i <= string.len(str) do
				local len = math.random(self.MinLength, self.MaxLength);
				table.insert(chunks, string.sub(str, i, i + len - 1));
				i = i + len;
			end
			
			if(#chunks > 1) then
				if math.random() < self.Treshold then
					if self.ConcatenationType == "strcat" then
						node = generateStrCatNode(chunks);
					elseif self.ConcatenationType == "table" then
						node = generateTableConcatNode(chunks, data);
					elseif self.ConcatenationType == "coustom" then
						if self.CoustomFunctionType == "global" then
							local args = generateCoustomNodeArgs(chunks, data, data.coustomFunctionVariant);
							-- Add Reference for Variable Renaming
							data.scope:addReferenceToHigherScope(data.coustomFuncScope, data.coustomFuncId);
							node = Ast.FunctionCallExpression(Ast.VariableExpression(data.coustomFuncScope, data.coustomFuncId), args);
						elseif self.CoustomFunctionType == "local" then
							local lfuncs = data.functionData.localFunctions;
							local idx = math.random(1, #lfuncs);
							local func = lfuncs[idx];
							local args = generateCoustomNodeArgs(chunks, data, func.variant);
							func.used = true;
							-- Add Reference for Variable Renaming
							data.scope:addReferenceToHigherScope(func.scope, func.id);
							node = Ast.FunctionCallExpression(Ast.VariableExpression(func.scope, func.id), args);
						elseif self.CoustomFunctionType == "inline" then
							local variant = self:variant();
							local args = generateCoustomNodeArgs(chunks, data, variant);
							local literal = generateCoustomFunctionLiteral(data.scope, variant);
							node = Ast.FunctionCallExpression(literal, args);
						end
					end
				end
			end
			
			return node, true;
		end
	end, data)
	
	
	if(self.ConcatenationType == "table") then
		local globalScope = data.globalScope;
		local tableScope, tableId = globalScope:resolve("table")
		ast.body.scope:addReferenceToHigherScope(globalScope, tableId);
		table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(data.tableConcatScope, {data.tableConcatId}, 
		{Ast.IndexExpression(Ast.VariableExpression(tableScope, tableId), Ast.StringExpression("concat"))}));
	elseif(self.ConcatenationType == "coustom" and self.CoustomFunctionType == "global") then
		table.insert(ast.body.statements, 1, generateGlobalCoustomFunctionDeclaration(ast, data));
	end
end

return SplitStrings;
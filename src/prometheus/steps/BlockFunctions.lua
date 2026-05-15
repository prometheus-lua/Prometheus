-- This Script is Custom for the Prometheus Obfuscator by VortexScripts
--
-- BlockFunctions.lua
--
-- This Script provides extra anti-tampering and anti-decompiling by blocking certain functions like print
-- This requires other steps to be modified before it can fully work.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser");
local VisitAst = require("prometheus.visitast");
local Unparser = require("prometheus.unparser")
local Enums = require("prometheus.enums");
local RandomLiterals = require("prometheus.randomLiterals");
local logger = require("logger")

local AstKind = Ast.AstKind

local BlockFunctions = Step:extend();
BlockFunctions.Description = "Blocks, or completely changes, builtin functions, making it harder to reverse engineer.";
BlockFunctions.Name = "Block Functions";

BlockFunctions.SettingsDescriptor = {
    MakeEnv = {
        description = "If we should create a new env to be used for other stuff (mainly loadstrings). Put __env in your table to reference the new environment",
        type = "boolean",
        default = false
    },
    Functions = {
        description = "A table with each function and their custom replacements",
        type = "table",
        default = { ["print"] = { Func = [[print("Sorry, you can't print that. :(")]], CClosure = false, Skip = false, Type = "function" }}
    },
}

function BlockFunctions:init(settings)

end

-- table.find isn't defined :(
local function IsInTable(t, e)
    for _, v in pairs(t) do
        if v == e then
            return true
        end
    end
    return false
end

local function CreateCode(self, pipeline)

    local NewVariables = {}

    -- Makes new variables for each Funcion
    for FunctionName, _ in pairs(self.Functions) do
        local New_Call = RandomLiterals.String(pipeline).value
        NewVariables[FunctionName] = New_Call
    end

    local TableCall = RandomLiterals.String(pipeline).value

    -- Every bit of code that will appear, in this order
    local SubstitutionCode = ""
    local ReplacementCode = ""
    if self.MakeEnv then
        SubstitutionCode = "local newenv = table.clone(getfenv()) "
    end

    for FunctionName, FunctionInfo in pairs(self.Functions) do
        if FunctionInfo.Type == "function" then
            local RFunc = FunctionInfo.Func or "return"
            SubstitutionCode = SubstitutionCode .. "getfenv()." .. NewVariables[FunctionName] .. " = " .. FunctionName .. " "
            local parsed = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(RFunc); -- This is the most accurate way to do this

            if self.MakeEnv and FunctionInfo.ReplaceEnvFunc and FunctionInfo.ReplaceEnvFunc ~= "" then
                local ERFunc = FunctionInfo.ReplaceEnvFunc
                local parsed2 = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(ERFunc)
                for Id, Variable in pairs(parsed2.globalScope:getVariables()) do
                    if self.Functions[Variable] then
                        parsed2.globalScope.variables[Id] = NewVariables[Variable]
                        parsed2.globalScope.variablesLookup[Variable] = Id
                    end
                end
                local NewERFunc = Unparser:new({LuaVersion = Enums.LuaVersion.LuaU}):unparse(parsed2)
                SubstitutionCode = SubstitutionCode .. "newenv." .. FunctionName .. " = function(...) " .. NewERFunc .. " end "
                -- print(SubstitutionCode)
            elseif self.MakeEnv then
                SubstitutionCode = SubstitutionCode .. "newenv." .. FunctionName .. " = " .. NewVariables[FunctionName] .. " "
            end

            -- Replace all function calls (variables) to the original ones, so the replaced ones don't get called
            for Id, Variable in pairs(parsed.globalScope:getVariables()) do
                if self.Functions[Variable] then
                    parsed.globalScope.variables[Id] = NewVariables[Variable]
                    parsed.globalScope.variablesLookup[Variable] = Id
                end
            end

            local NewRFunc = Unparser:new({LuaVersion = Enums.LuaVersion.LuaU}):unparse(parsed)

            -- Add the new function to the reference table.
            -- if self.MakeEnv then
            --     TableWFuncs = TableWFuncs .. "['" .. FunctionName .. "'] = '" .. NewVariables[FunctionName] .. "', "
            -- end

            -- Prepare the new replacement statement
            ReplacementCode = ReplacementCode .. "getfenv()." .. FunctionName .. " = "
            if FunctionInfo.CClosure then
                -- We may have replaced this function, so we check if we do.
                local Closure = NewVariables["newcclosure"] or "newcclosure"
                ReplacementCode = ReplacementCode .. Closure .. "(function(...) " .. NewRFunc .. " end) "
            else
                ReplacementCode = ReplacementCode .. "function(...) " .. NewRFunc .. " end "
            end
        else

            -- It's the same thing as above, we just don't wrap it in a function.

            local Statement = FunctionInfo.Func or "{}"
            local parsed = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(Statement);
            for Id, Variable in pairs(parsed.globalScope:getVariables()) do
                if self.Functions[Variable] then
                    parsed.globalScope.variables[Id] = NewVariables[Variable]
                    parsed.globalScope.variablesLookup[Variable] = Id
                end
            end

            local NewStatement = Unparser:new({LuaVersion = Enums.LuaVersion.LuaU}):unparse(parsed)

            SubstitutionCode = SubstitutionCode .. "getfenv()." .. NewVariables[FunctionName] .. " = " .. FunctionName .. " "
            if self.MakeEnv and FunctionInfo.ReplaceEnvFunc and FunctionInfo.ReplaceEnvFunc ~= "" then
                local ERFunc = FunctionInfo.ReplaceEnvFunc
                local parsed2 = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(ERFunc)
                for Id, Variable in pairs(parsed2.globalScope:getVariables()) do
                    if self.Functions[Variable] then
                        parsed.globalScope.variables[Id] = NewVariables[Variable]
                        parsed.globalScope.variablesLookup[Variable] = Id
                    end
                end
                local NewERFunc = Unparser:new({LuaVersion = Enums.LuaVersion.LuaU}):unparse(parsed2)
                SubstitutionCode = SubstitutionCode .. "newenv." .. FunctionName .. " = function(...) " .. NewERFunc .. " end "
            elseif self.MakeEnv then
                SubstitutionCode = SubstitutionCode .. "newenv." .. FunctionName .. " = " .. NewVariables[FunctionName] .. " "
            end

            ReplacementCode = ReplacementCode .. "getfenv()." .. FunctionName .. " = " .. NewStatement .. " "
        end
    end

    local code = "do " .. SubstitutionCode .. ReplacementCode .. " end"

    return code, NewVariables

end

function BlockFunctions:apply(ast, pipeline)

    -- These are the default steps that are included.
    -- These steps cannot appear after this step. It will cause issues if so.
    -- These are also the steps where you have to insert the global scope to your own table
    local NotAfter = {
        "Anti Tamper",
        "Constant Array",
        "Encrypt Strings",
        "Proxify Locals",
        "Split Strings",
    }

    local steps = pipeline.steps
    local Found
    for i = 1, #steps do
        if steps[i].Name == "Block Functions" then
            if Found then
                logger:error("You have this step more than once. Please only have this step once.")
            end
            Found = true
        end
        if Found then
            if IsInTable(NotAfter, steps[i].Name) then
                logger:error("You cannot have step \"" .. steps[i].Name .. "\" after the \"Block Functions\" step, due to how it works. Please have \"Block Functions\" after this step. ")
            end
        end
    end

    local Code, NewVariables = CreateCode(self, pipeline)



    if Code then
		-- Gets other steps
		for _,Child in pairs(ast.body.scope.children) do
			if Child.variablesFromHigherScopes then
				for Scope, _ in pairs(Child.variablesFromHigherScopes) do
					for Id, OgName in pairs(Scope:getVariables()) do
						if self.Functions[OgName] then
							if not self.Functions[OgName].Skip then
								Scope.variables[Id] = NewVariables[OgName]
								Scope.variablesLookup[OgName] = Id
							end
						end
					end
				end
			end
		end

        -- Renames them on a global level.
        for Id, originalName in pairs(ast.globalScope:getVariables()) do
            if self.Functions[originalName] then
                if not self.Functions[originalName].Skip then
                    ast.globalScope.variables[Id] = NewVariables[originalName]
                    ast.globalScope.variablesLookup[originalName] = Id
                end
            end
        end

        -- Insert the code

        local parsed = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(Code)
        local doStat = parsed.body.statements[1]

        doStat.body.scope:setParent(ast.body.scope)
        table.insert(ast.body.statements, 1, doStat);

        return ast
    end
    return ast
end

return BlockFunctions
-- Common calls and returns pass fixed value lists directly through native Lua.
local Kind = require('prometheus.ast').AstKind
local unpackValues = unpack or table.unpack

return function(Compiler, packList, expandable)
    function Compiler:call(node, count, tail)
        local fn, prefix
        if node.kind == Kind.PassSelfFunctionCallExpression then
            local object = self:expression(node.base, 1)[1]
            local key = self:load(node.passSelfFunctionName)
            fn = self:alloc(); self:emit('GETTABLE', fn, object, key)
            self:free(key)
            prefix = {object}
        else
            fn = self:expression(node.base, 1)[1]
        end

        local arity = #node.args + (prefix and 1 or 0)
        local fixed = arity <= 3 and not expandable(node.args[#node.args])
        local args, registers
        if fixed then
            registers = prefix or {}
            for _, argument in ipairs(node.args) do
                registers[#registers + 1] = self:expression(argument, 1)[1]
            end
            args = registers
        else
            args = packList(self, node.args, prefix)
        end
        local function releaseArguments()
            if fixed then
                for _, register in ipairs(registers) do self:free(register) end
            else
                self:free(args)
            end
            self:free(fn)
        end
        if tail then
            self:emit(fixed and ('TAILCALL' .. arity) or 'TAILCALL', fn, args)
            releaseArguments()
            return {}
        end
        local mode = count == 0 and 0 or (count == 1 and 1 or -1)
        local result = count ~= 0 and self:alloc() or 0
        self:emit(fixed and ('CALL' .. arity) or 'CALL', result, fn, args, mode)
        releaseArguments()
        if count == 0 then return {} end
        if count == -1 or count == 1 then return {result} end
        local results = {}
        for i = 1, count do
            results[i] = self:alloc(); self:emit('TAKE', results[i], result, i)
        end
        self:free(result)
        return results
    end

    function Compiler:fixedReturn(expressions)
        if #expressions > 3 or expandable(expressions[#expressions]) then return false end
        local registers = self:list(expressions, #expressions)
        self:emit('RETURN' .. #registers, unpackValues(registers))
        for _, register in ipairs(registers) do self:free(register) end
        return true
    end
end

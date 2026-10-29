-- Parse function attributes separately from runtime expressions and type erasure.
local Ast = require('prometheus.ast')
local logger = require('logger')
local K = Ast.AstKind

return function(Parser, token, is, consume, expect, peek, get)
    local function fail(self, message)
        local tk = peek(self)
        logger:error(string.format('Parsing Error at Position %s:%s, %s', tk.line, tk.linePos, message))
    end
    local function literal(node)
        if node.isParenthesizedExpression then return false end
        if node.kind == K.StringExpression or node.kind == K.NumberExpression
            or node.kind == K.BooleanExpression or node.kind == K.NilExpression then return true end
        if node.kind ~= K.TableConstructorExpression then return false end
        for _, entry in ipairs(node.entries) do
            if entry.key and not literal(entry.key) then return false end
            if not literal(entry.value) then return false end
        end
        return true
    end

    function Parser:parseLuauAttributes(scope)
        if self.luaVersion ~= 'LuaU' or not is(self, token.Symbol, '@') then return nil end
        local attributes, seen = {}, {}
        local function attribute(listed)
            local name = expect(self, token.Ident).value
            if name ~= 'native' and name ~= 'checked' and name ~= 'deprecated' then fail(self, 'Invalid function attribute ' .. name) end
            if seen[name] then fail(self, 'Duplicate function attribute ' .. name) end
            seen[name] = true
            local args = {}
            if listed then
                local savedSimplify = self.noSimplify
                self.noSimplify = true
                if consume(self, token.Symbol, '(') then
                    if not is(self, token.Symbol, ')') then args = self:exprList(scope) end
                    expect(self, token.Symbol, ')')
                elseif is(self, token.Symbol, '{') then
                    args = {self:tableConstructor(scope)}
                elseif is(self, token.String) then
                    args = {Ast.StringExpression(get(self).value)}
                end
                self.noSimplify = savedSimplify
            end
            for _, arg in ipairs(args) do if not literal(arg) then fail(self, 'Only literals are allowed in attributes') end end
            if name == 'deprecated' then
                if #args > 1 then fail(self, 'Deprecated accepts at most one argument') end
                local arg = args[1]
                if arg and arg.kind ~= K.TableConstructorExpression then fail(self, 'Deprecated requires a table literal') end
                if arg then
                    for _, entry in ipairs(arg.entries) do
                        if not entry.isRecord or not entry.key or entry.key.kind ~= K.StringExpression
                            or (entry.key.value ~= 'use' and entry.key.value ~= 'reason')
                            or entry.value.kind ~= K.StringExpression then
                            fail(self, 'Deprecated table accepts only string fields use and reason')
                        end
                    end
                end
            end
        end
        while is(self, token.Symbol, '@') do
            local first = self.index + 1
            local at = get(self)
            if peek(self).startPos ~= at.endPos then fail(self, "Expected an attribute name or '[' immediately after '@'") end
            if consume(self, token.Symbol, '[') then
                attribute(true)
                while consume(self, token.Symbol, ',') do attribute(true) end
                expect(self, token.Symbol, ']')
            else
                attribute(false)
            end
            local pieces = {}
            for i = first, self.index do pieces[#pieces + 1] = self.tokens[i].source end
            attributes[#attributes + 1] = table.concat(pieces, ' '):gsub('^@ ', '@')
        end
        return attributes
    end
end

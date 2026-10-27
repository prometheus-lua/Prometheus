-- Semantic instruction IDs for compiler IR. Emission assigns randomized IDs.
local names = {
    'LOAD', 'NIL', 'MOVE', 'CLEAR', 'CELL', 'GETCELL', 'SETCELL',
    'GETUP', 'SETUP', 'GLOBAL', 'SETGLOBAL', 'GETTABLE', 'SETTABLE',
    'TABLE', 'EXPAND', 'ARGS', 'TAKE', 'VARARG', 'CALL', 'RETURN',
    'TAILCALL', 'CLOSURE', 'JMP', 'JFALSE', 'JTRUE',
    'ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'CONCAT',
    'LT', 'LE', 'GT', 'GE', 'EQ', 'NE', 'NOT', 'NEG', 'LEN',
    'FORPREP', 'FORCHECK',
    'CLEARS', 'CALL0', 'CALL1', 'CALL2', 'CALL3',
    'TAILCALL0', 'TAILCALL1', 'TAILCALL2', 'TAILCALL3',
    'RETURN0', 'RETURN1', 'RETURN2', 'RETURN3',
}
local opcodes = {}
for id, name in ipairs(names) do opcodes[name] = id end
return opcodes

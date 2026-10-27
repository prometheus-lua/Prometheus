-- Semantic instruction IDs for the baseline VM. Layout mutation is a later pass.
local names = {
    'LOAD', 'NIL', 'MOVE', 'CLEAR', 'CELL', 'GETCELL', 'SETCELL',
    'GETUP', 'SETUP', 'GLOBAL', 'SETGLOBAL', 'GETTABLE', 'SETTABLE',
    'TABLE', 'EXPAND', 'ARGS', 'TAKE', 'VARARG', 'CALL', 'RETURN',
    'TAILCALL', 'CLOSURE', 'JMP', 'JFALSE', 'JTRUE',
    'ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'CONCAT',
    'LT', 'LE', 'GT', 'GE', 'EQ', 'NE', 'NOT', 'NEG', 'LEN',
    'FORPREP', 'FORCHECK',
}
local opcodes = {}
for id, name in ipairs(names) do opcodes[name] = id end
return opcodes

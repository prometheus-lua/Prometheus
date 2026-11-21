-- Declares, per opcode, which IR operand slots are plain numbers (register
-- indices, constant indices, jump targets, small control flags) versus
-- opaque values that are not numbers (register-list tables used by ARGS,
-- CLOSURE's capture list is read via the child prototype, CLEARS' register
-- list, and the fixed-arity CALL/TAILCALL family's args table).
--
-- Instructions are {opcode, operand2, operand3, operand4, operand5} in
-- compiler IR (see vm/compiler.lua Compiler:emit). This table is indexed by
-- opcode *name* and lists, for operand positions 2..5, whether the operand
-- at that position is a plain number ('N') or must be left alone ('X').
-- Positions beyond the listed length do not occur for that opcode.
--
-- EncryptOperands (vm/encrypt_operands.lua) uses this to decide which
-- operand values join the running cipher stream; the generated runtime
-- decrypts exactly those same positions, for exactly those opcodes, using
-- a layout-independent per-opcode arity table derived from this file.

local signatures = {
    LOAD = {'N', 'N'},
    NIL = {'N'},
    MOVE = {'N', 'N'},
    CLEAR = {'N'},
    CELL = {'N', 'N'},
    GETCELL = {'N', 'N'},
    SETCELL = {'N', 'N'},
    GETUP = {'N', 'N'},
    SETUP = {'N', 'N'},
    GLOBAL = {'N', 'N'},
    SETGLOBAL = {'N', 'N'},
    GETTABLE = {'N', 'N', 'N'},
    SETTABLE = {'N', 'N', 'N'},
    TABLE = {'N'},
    EXPAND = {'N', 'N', 'N'},
    ARGS = {'N', 'X', 'N'},
    TAKE = {'N', 'N', 'N'},
    VARARG = {'N'},
    RETURN = {'N'},
    CLOSURE = {'N', 'N'},
    JMP = {'N'},
    JFALSE = {'N', 'N'},
    JTRUE = {'N', 'N'},
    ADD = {'N', 'N', 'N'},
    SUB = {'N', 'N', 'N'},
    MUL = {'N', 'N', 'N'},
    DIV = {'N', 'N', 'N'},
    MOD = {'N', 'N', 'N'},
    POW = {'N', 'N', 'N'},
    CONCAT = {'N', 'N', 'N'},
    LT = {'N', 'N', 'N'},
    LE = {'N', 'N', 'N'},
    GT = {'N', 'N', 'N'},
    GE = {'N', 'N', 'N'},
    EQ = {'N', 'N', 'N'},
    NE = {'N', 'N', 'N'},
    NOT = {'N', 'N'},
    NEG = {'N', 'N'},
    LEN = {'N', 'N'},
    FORPREP = {'N', 'N', 'N'},
    FORCHECK = {'N', 'N', 'N', 'N'},
    CALL = {'N', 'N', 'X', 'N'},
    TAILCALL = {'N', 'X'},
    RETURN0 = {},
    RETURN1 = {'N'},
    RETURN2 = {'N', 'N'},
    RETURN3 = {'N', 'N', 'N'},
    CLEARS = {'X'},
}

-- Fixed-arity call/tailcall families: args/registers table is opaque ('X');
-- everything else numeric.
for arity = 0, 3 do
    signatures['CALL' .. arity] = {'N', 'N', 'X', 'N'}
    signatures['TAILCALL' .. arity] = {'N', 'X'}
end

return signatures

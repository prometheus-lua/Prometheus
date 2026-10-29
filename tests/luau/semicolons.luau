type Value = number;
export type Exported = Value;
type function Identity(value) return value end;
local value: Exported = 0;
do value += 1; end;
if value == 1 then value += 1; else error('wrong branch'); end;
while value < 10 do
    value += 1;
    if value == 3 then continue; end;
    break;
end;
repeat value += 1; until true;
for i = 1, 2 do value += i; end;
local function stop()
    repeat return; until true;
end;
stop();
(function() value += 1; end)();
assert(value == 9);
print('Semicolon checks passed');

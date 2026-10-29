#!/usr/bin/env python3
"""Validate recent Luau values using a Lua 5.1 or LuaJIT obfuscator host."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
lua = os.environ.get('LUA51', 'lua5.1')
luau = os.environ.get('LUAU', 'luau')
names = ('Minify', 'Cff', 'Vmify', 'Weak', 'Medium', 'Strong')


def run(args):
    result = subprocess.run(args, cwd=root, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return result.stdout


def execute(source, fixture, runner):
    delimiter = '='
    while ']' + delimiter + ']' in source:
        delimiter += '='
    quoted = '[' + delimiter + '[' + source + ']' + delimiter + ']'
    checks = ''
    if fixture.stem == 'exports':
        checks = '''
assert(type(result) == 'table' and table.isfrozen(result))
assert(result.counter == 3 and result.fixed == 2 and result.optional == nil)
local first, second = result.get()
assert(first == 3 and second == 2)
assert(not pcall(result.increment))
assert(not pcall(function() result.fixed = 9 end))
print('Value exports, module return, and freezing checks passed')
'''
    runner.write_text('local result = assert(loadstring(' + quoted + '))()\n' + checks)
    return run([luau, str(runner)])


count = 0
with tempfile.TemporaryDirectory(prefix='prometheus-recent-luau-') as directory:
    directory = Path(directory)
    output, runner = directory / 'output.luau', directory / 'run.luau'
    for fixture in sorted((root / 'tests/luau/recent').glob('*.luau')):
        expected = execute(fixture.read_text(), fixture, runner)
        for index, name in enumerate(names, 1):
            for seed in (1, 17):
                run([lua, 'scripts/test/obfuscate.lua', 'tests/luau/test-config.lua',
                     str(index), str(seed), str(fixture), str(output)])
                actual = execute(output.read_text(), fixture, runner)
                assert actual == expected, (fixture.name, name, seed, expected, actual)
                count += 1
        print(f'{fixture.name}: all presets passed', flush=True)
print(f'{count} recent Luau transformations matched their baseline')

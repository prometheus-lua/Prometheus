#!/usr/bin/env python3
"""Compare Luau fixtures with the output of each obfuscation pipeline."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
lua = os.environ.get('LUA51', 'lua5.1')
luau = os.environ.get('LUAU', 'luau')
names = ('Minify', 'Cff', 'Vmify', 'Weak', 'Medium', 'Strong')


def run(args):
    return subprocess.run(args, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=60, check=True).stdout


count = 0
with tempfile.TemporaryDirectory(prefix='prometheus-luau-') as tmp:
    output = str(Path(tmp) / 'output.luau')
    for fixture in sorted((root / 'tests/luau').glob('*.luau')):
        expected = run([luau, str(fixture)])
        for index, name in enumerate(names, 1):
            for seed in (1, 17):
                try:
                    run([lua, 'scripts/test/obfuscate.lua', 'tests/luau/test-config.lua',
                         str(index), str(seed), str(fixture), output])
                    actual = run([luau, output])
                except subprocess.CalledProcessError as exc:
                    raise AssertionError(f'{fixture.name}, {name}, seed {seed}:\n{exc.stderr}\n{exc.stdout}') from exc
                assert actual == expected, (f'{fixture.name}, {name}, seed {seed}: '
                                            f'expected {expected!r}, got {actual!r}')
                count += 1
        print(f'{fixture.name}: all presets passed', flush=True)
    for invalid in sorted((root / 'tests/luau/invalid').glob('*.luau')):
        baseline = subprocess.run([luau, str(invalid)], cwd=root, capture_output=True, text=True, timeout=60)
        transformed = subprocess.run([lua, 'scripts/test/obfuscate.lua', 'tests/luau/test-config.lua',
                                      '1', '1', str(invalid), output], cwd=root,
                                     capture_output=True, text=True, timeout=60)
        assert baseline.returncode != 0 and transformed.returncode != 0, invalid.name
    print('Invalid type, const, and interpolation examples were rejected', flush=True)
    fixture = root / 'tests/luau/unsupported/protected-metatable.luau'
    assert run([luau, str(fixture)]) == '1\n'
    for index in (2, 3):
        run([lua, 'scripts/test/obfuscate.lua', 'tests/luau/test-config.lua',
             str(index), '1', str(fixture), output])
        result = subprocess.run([luau, output], cwd=root, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, timeout=60)
        assert result.returncode != 0 and 'protected metatable' in result.stderr
print(f'{count} Luau transformations matched their baseline')
print('Protected metatables are rejected by Cff and Vmify')

#!/usr/bin/env python3
"""Exercise CLI argument handling using the real Lua interpreter."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
lua = os.environ.get('LUA51', 'lua5.1')
cli = root / 'cli.lua'


def run(args, cwd, success=True):
    result = subprocess.run([lua, str(cli), *map(str, args)], cwd=cwd,
                            capture_output=True, text=True, timeout=60)
    if (result.returncode == 0) != success:
        raise AssertionError(f'{args!r}: exit {result.returncode}\n{result.stdout}\n{result.stderr}')
    return result


def execute(path, cwd):
    result = subprocess.run([lua, str(path)], cwd=cwd, capture_output=True, text=True, timeout=60, check=True)
    assert result.stdout == '42\n', result.stdout


with tempfile.TemporaryDirectory(prefix='prometheus-cli-') as directory:
    tmp = Path(directory)
    source = tmp / 'Mixed Source.LUAU'
    source.write_text('local value: number = 41\nprint(value + 1)\n')

    for index, preset in enumerate(('minify', 'WEAK', 'cFf', 'vMiFy', 'medium', 'STRONG')):
        output = tmp / f'Output {index}.lua'
        run(['--PRESET', preset, '--luau', '--NoCoLoRs', '--OUT', output, source], tmp)
        execute(output, tmp)

    output = tmp / 'MixedCase.lua'
    run(['--PrEsEt=MiNiFy', '--lUaU', '--o=' + str(output), source], tmp)
    execute(output, tmp)
    run(['--p', 'MINIFY', '--LuaU', '--O', output, source], tmp)
    execute(output, tmp)

    config = tmp / 'My Config.LUA'
    config.write_text('return {LuaVersion = "LuaU", Seed = 1, Steps = {}}\n')
    run(['--CONFIG=' + str(config), '--OUT=' + str(output), source], tmp)
    execute(output, tmp)
    run(['--C', config, '--O', output, source], tmp)
    execute(output, tmp)

    run(['--PrEsEt', 'minify', '--LUAU', source], tmp)
    execute(tmp / 'Mixed Source.obfuscated.LUAU', tmp)
    normal = tmp / 'Input.lua'
    normal.write_text('print(42)\n')
    run(['--lua51', '--p=minify', normal], tmp)
    execute(tmp / 'Input.obfuscated.lua', tmp)
    no_extension = tmp / 'Input'
    no_extension.write_text('print(42)\n')
    run(['--Lua51', '--p=minify', no_extension], tmp)
    execute(tmp / 'Input.obfuscated.lua', tmp)

    (tmp / '--input.lua').write_text('print(42)\n')
    run(['--preset=minify', '--OUT=--result.lua', '--', '--input.lua'], tmp)
    execute(tmp / '--result.lua', tmp)
    assert 'Usage:' in run(['--HELP'], tmp).stdout
    assert 'Usage:' in run([normal, '--HELP'], tmp).stdout
    assert run(['--VERSION'], tmp).stdout.strip()
    assert run([normal, '-V'], tmp).stdout.strip()

    failures = [
        (['--luau', '--preset'], 'requires a value'),
        (['--out'], 'requires a value'),
        (['--CONFIG', '--luau', normal], 'requires a value'),
        (['--out=', normal], 'requires a value'),
        (['--out', '', normal], 'requires a value'),
        (['--luau=true', normal], 'does not accept a value'),
        (['--UNKNOWN', normal], 'Unknown option'),
        (['--UNKNOWN=value', normal], 'Unknown option'),
        (['-unknown', normal], 'Unknown option'),
        (['--preset', 'NotARealPreset', normal], 'NotARealPreset'),
        ([normal, source], 'Unexpected argument'),
        (['--SAVEERRORS'], 'No input file was specified'),
        (['--out=' + str(tmp / 'missing' / 'out.lua'), normal], 'Cannot write output file'),
    ]
    for args, message in failures:
        result = run(args, tmp, success=False)
        assert message in result.stderr, (args, result.stderr)
        assert "attempt to index" not in result.stderr

    mock_update = tmp / 'mock-update.lua'
    mock_update.write_text("""local cli = arg[1]
arg = {'UPDate'}
os.execute = function() return 0 end
os.exit = function(status) error('mock exit: ' .. status) end
local ok, err = pcall(dofile, cli)
assert(not ok and tostring(err):find('mock exit: 0', 1, true))
""")
    subprocess.run([lua, str(mock_update), str(cli)], cwd=tmp, capture_output=True,
                   text=True, timeout=60, check=True)

    malformed_type = tmp / 'MalformedType.luau'
    malformed_type.write_text('local x: |& usudhd  subd = 100\n')
    rejected_output = tmp / 'RejectedOutput.luau'
    for preset in ('minify', 'cff', 'vmify', 'weak', 'medium', 'strong'):
        result = run(['--luau', '--preset', preset, '--out', rejected_output, malformed_type], tmp, success=False)
        assert 'Expected a type' in result.stderr and '1:11' in result.stderr, result.stderr
        assert not rejected_output.exists()

    invalid = tmp / 'Invalid.LUAU'
    invalid.write_text('local value: = 1\n')
    run(['--SaVeErRoRs', '--luau', '--preset=minify', invalid], tmp, success=False)
    assert 'Parsing Error' in (tmp / 'Invalid.error.txt').read_text()
print('CLI case handling, paths, options, and diagnostics passed')

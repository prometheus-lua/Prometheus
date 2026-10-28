#!/usr/bin/env python3
"""Compare type syntax acceptance and erasure against the official Luau compiler."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
lua = os.environ.get('LUA51', 'lua5.1')
compiler = os.environ.get('LUAU_COMPILE', 'luau-compile')
cases = []


def add(label, source, expected=None):
    cases.append((label, source, expected))


# These are syntax checks, not type checking: unknown names are valid type references.
add('reported regression', 'local x: |& usudhd  subd  = 100', False)
add('unknown type', 'local x: UnknownType = nil', True)
add('adjacent statement', 'local x: UnknownType subd = 100', True)
add('grouped combinations', 'type T = (Foo | Bar) & Baz', True)
add('ungrouped combinations', 'type T = Foo | Bar & Baz', False)

forms = [
    'number', 'nil', 'true', 'false', '"tag"', '[=[tag]=]', 'Foo', 'Pkg.Value', 'Pkg.Sub.Value',
    '| Foo', '& Foo', '|& Foo', '&| Foo', '|| Foo', '&& Foo', '|', '&', '?',
    'Foo | Bar', 'Foo & Bar', 'Foo | Bar & Baz', 'Foo & Bar | Baz',
    'Foo | & Bar', 'Foo & | Bar', 'Foo?', 'Foo??', 'Foo? & Bar', 'Foo & Bar?',
    '(Foo | Bar) & Baz', '(Foo & Bar) | Baz', 'Foo & (Bar?)', '(Foo & Bar)?',
    '()', '(Foo)', '((Foo))', '(Foo, Bar)', '(name: Foo)', '(Foo,)', '(Foo)?', '(Foo, Bar)?',
    '...', '...Foo', 'Foo...', 'Pkg.Value...', 'Foo...?','(Foo...)', '(...Foo)', '(Foo, ...Bar)',
    '() -> ()', '(Foo) -> Bar', '(name: Foo, other: Bar) -> (Foo, Bar)',
    '(Foo, ...Bar) -> (Foo, ...Bar)', '(Foo..., Bar) -> Baz', '(...Foo, Bar) -> Baz',
    '(Foo...) -> Bar', '(Foo,) -> Bar', '() ->', '() : Foo', '() -> () -> Foo',
    '<T>(T) -> T', '<T, P...>(T, P...) -> (T, P...)', '<T = Foo>(T) -> T',
    '<T..., U>(T...) -> U', '<T,>(T) -> T', '<>(Foo) -> Bar',
    'Container<>', 'Container<Foo>', 'Container<Foo, Bar>', 'Container<Foo,>',
    'Container<,Foo>', 'Container<Foo = Bar>', 'Container<...Foo, Bar>',
    'Container<(Foo, Bar)>', 'Container<()>', 'Container<(Foo)?>', 'Container<(Foo, Bar)?>',
    'Container<(Foo) | Bar>', 'Container<Foo<Bar<Baz>>>', 'Container<Foo...>',
    '{}', '{Foo}', '{Foo,}', '{Foo, Bar}', '{{x: Foo}}', '{x: Foo}',
    '{x: Foo, y: Bar;}', '{x: Foo, Bar}', '{read x: Foo, write y: Bar}',
    '{read: Foo, write: Bar}', '{read Foo}', '{read}', '{readonly x: Foo}',
    '{[Foo]: Bar}', '{[Foo]: Bar, [Baz]: Qux}', '{["key"]: Foo, [Bar]: Baz}',
    '{["bad\\000"]: Foo}', '{...Foo}', '{x: () -> (Foo, Bar)}',
    'typeof(value)', 'typeof({value = 1})', 'typeof((function() return 1 end)())',
    'typeof()', 'typeof(+)', 'typeof(value other)', 'typeof(1, 2)', 'typeof({x = })',
    'typeof', 'typeof.Prefix', 'typeof(function(x: |& Foo) return x end)',
    '`not a singleton`', '123', 'function',
]
contexts = [
    ('local annotation', 'local x: %s = nil'),
    ('function parameter', 'local function f(x: %s) end'),
    ('vararg annotation', 'local function f(...: %s) end'),
    ('return annotation', 'local function f(): %s return nil end'),
    ('type alias', 'type Alias = %s'),
    ('type assertion', 'local x = nil :: %s'),
    ('type argument', 'type Alias = Container<%s>'),
]
for form in forms:
    for context, template in contexts:
        add(f'{context}: {form}', template % form)

# Generic declarations differ from applications and allow defaults only in aliases.
parameters = [
    'T', '', 'T,', ',T', 'number?', 'Pkg.T', 'T | U', 'T & U',
    'T, U', 'T...', 'T, P...', 'P..., T', 'P..., Q...', 'T...,',
    'T = number', 'T = number, U', 'T = number, U = string',
    'T, U = number', 'T = number, P...', 'T = number, P... = ()',
    'P... = ()', 'P... = (Foo, Bar)', 'P... = ...Foo', 'P... = Q...',
    'P... = Foo', 'P... = (Foo)?', 'P... = (Foo, ...Bar)',
    'P... = (), Q...', 'P... = (), Q... = ()', 'T = (Foo, Bar)',
]
for params in parameters:
    add(f'alias generics: {params}', f'type Alias<{params}> = number')
    add(f'function generics: {params}', f'local function f<{params}>() end')
    add(f'anonymous generics: {params}', f'local f = function<{params}>() end')
    add(f'function type generics: {params}', f'type Alias = <{params}>() -> ()')

# Mutate complete types in multiple contexts so malformed input cannot simply be erased.
for op in ('|', '&'):
    for following in ('Foo', '?', '| Bar', '& Bar', ')', '...', ''):
        add(f'operator sequence: {op} {following}', f'local x: {op} {following} = nil')
    for suffix in ('', '|', '&', 'Foo', '()', ', Bar', '; Bar'):
        add(f'unfinished chain: {op} {suffix}', f'type Alias = Foo {op} {suffix}')

for expr in ('1 +', '{x = }', 'value other', 'function() local x: |& T = 1 end', 'if true then 1'):
    add(f'typeof malformed expression: {expr}', f'type Alias = typeof({expr})', False)
add('typeof does not execute', 'type Alias = typeof(error("not executed"))', True)
add('valid type function signature', 'type function f<T, P...>(x: T, ...: P...): T return x end', True)
add('invalid type function generics', 'type function f<T = number>() end', False)



# Token-level edits of valid compound types exercise malformed boundaries and nesting.
seeds = [
    ['Foo', '|', 'Bar'],
    ['(', 'Foo', '&', 'Bar', ')', '?'],
    ['{', 'field', ':', 'Foo', ',', '[', 'Bar', ']', ':', 'Baz', '}'],
    ['(', 'Foo', ',', '...', 'Bar', ')', '->', '(', 'Baz', ',', 'Qux', '...', ')'],
    ['Container', '<', 'Foo', ',', '(', 'Bar', ',', 'Baz', ')', '>'],
    ['<', 'T', ',', 'P', '...', '>', '(', 'T', ',', 'P', '...', ')', '->', '(', 'T', ',', 'P', '...', ')'],
    ['typeof', '(', '{', 'field', '=', '1', '}', ')'],
]
mutations = set()
for seed in seeds:
    for index in range(len(seed)):
        mutations.add(' '.join(seed[:index] + seed[index + 1:]))
    for index in range(len(seed) + 1):
        for inserted in ('|', '&', '?', ',', ':', '...', 'Foo'):
            mutations.add(' '.join(seed[:index] + [inserted] + seed[index:]))
for index, form in enumerate(sorted(mutations)):
    add(f'mutation local {index}', 'local x: ' + form + ' = nil')
    add(f'mutation alias {index}', 'type Alias = ' + form)


def official(path):
    result = subprocess.run([compiler, '--binary', str(path)], cwd=root,
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                            text=True, timeout=10)
    assert result.returncode in (0, 1), (path, result.returncode, result.stderr)
    return result.returncode == 0, result.stderr


with tempfile.TemporaryDirectory(prefix='prometheus-type-syntax-') as directory:
    temporary = Path(directory)
    paths = []
    for index, (_, source, _) in enumerate(cases):
        path = temporary / f'{index:04d}.luau'
        path.write_text(source)
        paths.append(path)
    manifest = temporary / 'manifest.txt'
    manifest.write_text(''.join(str(path) + '\n' for path in paths))
    run = subprocess.run([lua, 'tests/harness/luau-syntax.lua', str(manifest)], cwd=root,
                         capture_output=True, text=True, timeout=60, check=True)
    parsed = run.stdout.splitlines()
    assert len(parsed) == len(cases), (len(parsed), len(cases), run.stdout[:500], run.stderr)
    differences = []
    accepted = rejected = 0
    for (label, source, expected), path, line in zip(cases, paths, parsed):
        native, error = official(path)
        assert expected is None or native == expected, (label, source, error)
        ours = line.split('\t', 1)[0] == 'accept'
        accepted += native
        rejected += not native
        if native != ours:
            differences.append(f'{label}\n  {source}\n  Luau: {native}; Prometheus: {line}\n  {error.strip()}')
        elif ours:
            output_ok, output_error = official(Path(str(path) + '.out.luau'))
            if not output_ok:
                differences.append(f'{label}: invalid type-erased output\n  {output_error}')
    assert not differences, f'{len(differences)} syntax mismatches:\n' + '\n'.join(differences[:25])
    print(f'{len(cases)} syntax cases match Luau: {accepted} accepted, {rejected} rejected; emitted code also compiled')

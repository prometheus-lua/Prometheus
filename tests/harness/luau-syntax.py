#!/usr/bin/env python3
"""Compare Luau syntax acceptance and emitted code against the official compiler."""
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


# Contextual words must remain usable in every identifier position.
for word in ('continue', 'type', 'export', 'const', 'typeof', 'read', 'write', 'declare'):
    for template in (
        'local %s = 1; return %s',
        'local function %s() end; %s()',
        'function %s() end; %s()',
        'local function f(%s) return %s end',
        'local t = {%s = 1}; return t.%s',
        'local t = {}; function t:%s() end; t:%s()',
        'for %s = 1, 2 do print(%s) end',
        'for %s in pairs({}) do print(%s) end',
        'type %s = number; local x: %s = 1',
    ):
        expected = not (word == 'typeof' and template.startswith('type '))
        add(f'contextual identifier {word}: {template}', template % (word, word), expected)
for source in (
    'continue', 'continue = 1', 'continue, x = 1, 2', 'continue += 1',
    'continue //= 2', 'continue()', 'continue {}', 'continue "text"',
    'continue.field = 1', 'continue[1] = 1', 'continue:method()',
    'while true do continue end', 'while true do (continue) end',
    'while true do continue; end', 'while true do continue;; end',
    'while true do continue; print(1) end',
    'while true do continue() print(1) end',
    'local continue = 1; while true do continue end',
    'const continue = 1; while true do continue end',
    'while true do local function f() continue end end',
    'repeat continue until true', 'while true do do continue end end',
    'type = 1; export = 2; const = 3',
    'type(number); export(); const()',
):
    add(f'contextual statement: {source}', source)

# Luau accepts a single trailing semicolon, never an empty statement.
for statement in (
    'local x = 1', 'x = 1', 'print()', 'do end', 'while true do break end',
    'for i = 1, 2 do end', 'repeat until true', 'function f() end',
    'local function f() end', 'type T = number', 'type function f() end',
    'const x = 1', 'export type T = number',
):
    for before in ('', ';', ';;'):
        for after in ('', ';', ';;'):
            for context in ('%s', 'do %s end', 'local function f() %s end'):
                source = context % (before + statement + after)
                add(f'semicolons: {source}', source, not before and len(after) <= 1)
for source in (
    '', ';', ';;', 'do ; end', 'return;', 'return;;',
    'repeat return until true', 'repeat return; until true',
    'while true do break; end', 'while true do break;; end',
    'type A = number; type B = A;', 'type A = number;; type B = A',
    'return {1; 2; x = 3;}', 'type T = {x: number; y: string;}',
    'print(); (function() end)()', 'print()\n(function() end)()',
    'local x = f\n(1)', 'local x = f(\n1\n)', 'f -- comment\n(1)',
    'object:method\n()', 'f\n{}', 'f\n"text"',
    'while true do continue\n(1) end',
):
    add(f'statement boundary: {source}', source)

# Variadic state belongs to the nearest function, including erased type syntax.
for signature in ('()', '(x)', '(...)', '(x, ...)'):
    for body in (
        'return ...', 'print(...)', 'do local x = ... end',
        'local f = function() return ... end',
        'local function f(...) return ... end; return ...',
        'local function f() return 1 end; return ...',
        'local x = `value={...}`', 'type T = typeof(...)',
        'local x: typeof(...)', 'type function f() return ... end',
        'type function f(...) return ... end; return ...',
        'local function f(x: typeof(...)): typeof(...) return x end',
    ):
        for declaration in ('local function f%s %s end', 'function t:f%s %s end',
                            'local f = function%s %s end'):
            source = declaration % (signature, body)
            add(f'vararg context: {source}', source)
for source in (
    'return ...', 'return (...)', 'local x: typeof(...) = ...',
    'local function f(): typeof(...) end',
    'local function f(...): typeof(...) return ... end',
    'local function f(x: typeof(...)) end',
    'local function f() end; return ...',
    'local function f(...) return function(...) return ... end end',
    'local function f(..., x) end', 'local function f(..., ...) end',
    'local function f() type T = typeof(function(...) return ... end) end',
):
    add(f'vararg boundary: {source}', source)

# Number-like tokens must be validated as a whole, including discarded types.
numerals = [
    '0', '01', '1.', '.5', '1_000', '1__2_', '1_.2_5', '1_e+_2_',
    '0xFF', '0Xff', '0_x_F_F_', '0b101', '0B101', '0_b_1_0_',
    '0b__1__0_', '1e999', '1e-999', '0x', '0b', '0x_', '0b_',
    '0b102', '0xFG', '0b0b1', '1e', '1e+', '1e_+2', '1..2',
    '1print()', '0x1.2', '0x1p2', '0x1p-2', '0x1e+2', '1e2.3',
]
for literal in ('1', '.5', '1.', '1e2', '0b1', '0xF', '0X1e'):
    for suffix in ('_', '__', 'e', 'e+', 'e-', 'e+_2', 'e_+2', '.', '..', 'a', 'p2', 'f'):
        numerals.append(literal + suffix)
for prefix, digit in (('0x', 'f'), ('0b', '1')):
    for length in (1, 8, 16, 17, 53, 64, 65, 128):
        numerals.append(prefix + digit * length)
for literal in sorted(set(numerals)):
    for template in ('return %s', 'local value = %s; print(value)', 'type T = typeof(%s)'):
        add(f'numeral: {template % literal}', template % literal)

for source in (
    'local a, b, c = 1, 2, 3; return a // b * c % 2 / 3',
    'local a, b = 1, 2; a //= b; return a',
    'local t = {x = 1}; t.x //= 2',
    'return -2 ^ 2 // 3', 'return 2 ^ -3 // 2',
    'return 1 /// 2', 'local a = 1; a //== 2',
):
    add(f'floor division: {source}', source)


# Attributes, explicit instantiations, and newer value syntax share runtime names.
for attribute in (
    '@native', '@checked', '@deprecated', '@[native]', '@[native, checked]',
    '@[deprecated({use = "replacement", reason = "old"})]',
    '@[native(1)]', '@[native("text", true, nil, {})]',
    '@[deprecated({})]', '@[deprecated("text")]', '@[deprecated(1)]',
    '@[deprecated({["use"] = "replacement"})]', '@[deprecated({bad = "x"})]',
    '@[deprecated({use = 1})]', '@[native(1 + 2)]', '@[native(-1)]',
    '@[native((1))]', '@[native(function() end)]', '@[native(value)]',
    '@[native({field = value})]', '@[native(1i)]', '@[native(-1i)]',
    '@[native, native]', '@native @native', '@[]', '@[native,]', '@unknown', '@ native',
):
    for template in ('%s local function f() end', '%s function f() end',
                     'local f = %s function() end', 'local %s function f() end', '%s local x = 1'):
        add(f'attribute: {attribute}: {template}', template % attribute)
for args in ('number', 'number, string', '', 'number,', '...number', 'T...',
             '(number, string)', 'number | string', 'typeof(1)', 'number = string', '|& T'):
    for template in ('return f<<%s>>(1)', 'return object:method<<%s>>(1)',
                     'return f<<%s>>', 'return f<<%s>>.field', 'return f<<%s>>[1]',
                     'return f<<%s>><<number>>(1)'):
        add(f'explicit instantiation: {template % args}', template % args)

for literal in ('0i', '01i', '1_000i', '9223372036854775807i', '9223372036854775808i',
                '-9223372036854775808i', '0xffffffffffffffffi', '0x10000000000000000i',
                '0b' + '1' * 64 + 'i', '0b' + '1' * 65 + 'i', '0x0001i',
                '0bi', '0xi', '1.0i', '1e2i', '.1i', '1ii', '0b2i'):
    add(f'integer literal: {literal}', 'return ' + literal)
for declaration in ('export local x = 1', 'export const x = 1', 'export function f() end',
                    'export local x', 'export local x, y = 1, 2',
                    'export local function f() end', 'export const function f() end'):
    for template in ('%s', 'do %s end', 'local function f() %s end',
                     '%s; return 1', 'do return 1 end; %s', '@native %s'):
        add(f'value exports: {template % declaration}', template % declaration)
for source in (
    'export local x = 1; export local x = 2',
    'export const x = 1; x = 2', 'export function f() end; f = 1',
    'export local x = 1; function x() end',
    'const x = 1; type T = typeof(function() x = 2 end)',
    'local x = 1; type function f() return x end',
    'type function f(x) return function() return x end end',
    'local x = 1; return x :: number :: number',
    'local x = 1; return (x :: number) :: number',
    'local x = 1; (x) = 2', 'local t = {}; (t.x) = 2',
    'local t = {}; (t).x = 2', 'local x, y = 1, 2; x, (y) = 3, 4',
):
    add(f'scope or lvalue validation: {source}', source)
for branch in ('if flag then continue end', 'if false then continue end',
               'if true then continue end', 'do continue end',
               'if false then continue elseif flag then continue end',
               'if true then print(1) else continue end'):
    for condition in ('value', '(function() return value end)()', 'true'):
        add(f'repeat continue: {branch}: {condition}', f'repeat {branch} local value = true until {condition}')
for ending in ('\n', '\r', '\r\n', '\n\r'):
    add(f'raw newline {ending!r}', 'return "a' + ending + 'b"')
    add(f'escaped newline {ending!r}', 'return "a\\' + ending + 'b"')
    add(f'comment newline {ending!r}', '-- comment' + ending + 'return 1')
for escape in (r'\u{}', r'\u{110000}', r'\u{D800}', r'\u{10FFFF}', r'\255', r'\256', r'\xFG', r'\q'):
    add('string escape ' + escape, 'return "' + escape + '"')


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

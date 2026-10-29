# Contributing to Prometheus

Thanks for contributing to Prometheus.

## Requirements

- Keep pull requests focused and small where possible.
- Follow the existing project style and structure.
- Ensure your changes do not break existing tests and behavior.
- Add or update tests when changing behavior.
- Document user-visible changes clearly.

## Running Tests

The obfuscator source must remain valid Lua 5.1 and run in both Lua 5.1 and
LuaJIT. `LuaVersion` selects the input/output dialect; Luau is a target runtime,
not a dependency of the obfuscator host. Tests run inside a Docker container
with Lua 5.1, LuaJIT, and the official Luau runtime:

```bash
./scripts/run-tests.sh           # Run all tests (default: 10 iterations)
./scripts/run-tests.sh -b        # Build image (needed first time or after Dockerfile changes)
./scripts/run-tests.sh -n 5      # Run with 5 iterations
./scripts/run-tests.sh -c config.lua  # Use a custom config
./scripts/run-tests.sh -v        # Verbose output
```

The Docker build runs Luau syntax and execution checks with both Lua 5.1 and
LuaJIT as the obfuscator host. The same checks can be run directly:

```bash
LUA51=luajit python3 tests/harness/luau-syntax.py
LUA51=luajit python3 tests/harness/luau.py
LUA51=luajit python3 tests/harness/luau-recent.py
luajit tests/harness/luau-strings.lua
```

`LUAU` and `LUAU_COMPILE` select the target runtime and compiler. The recent
syntax checks require a Luau version with value exports and integer literals.

### Test File Metadata

Test files can include metadata comments at the top of the file:

| Annotation | Effect |
|-----------|--------|
| `-- @skip` | Skip this test entirely |
| `-- @luau-only` | Only run with Luau |
| `-- @runtime lua51 luajit` | Only run with specified runtimes |
| `-- @skip-preset Weak` | Skip a specific preset for this test |

## Reporting Bugs

When opening a bug report, include:

- Clear bug description
- Expected behavior
- Steps to reproduce
- A minimal reproducible example shared via the Prometheus Playground: https://prometheus-lua.github.io/Prometheus/
- Config used (preset/custom config)
- Produced output and relevant errors/logs
- Environment details (OS, Lua/LuaJIT version)

Bug reports without a reproducible minimal example may be closed until reproducible information is provided.

## Contributing New Steps / Features

If a new step or feature might break existing scripts:

- It must be clearly documented as potentially breaking.
- It must not be added to any default pipeline.
- It should only be available through custom configuration.

When proposing such a change, include migration guidance and examples for users.

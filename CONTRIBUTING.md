# Contributing to Prometheus

Thanks for contributing to Prometheus.

## Requirements

- Keep pull requests focused and small where possible.
- Follow the existing project style and structure.
- Ensure your changes do not break existing tests and behavior.
- Add or update tests when changing behavior.
- Document user-visible changes clearly.

## Running Tests

Tests run inside a Docker container with lua5.1 and Luau:

```bash
./scripts/run-tests.sh           # Run all tests (default: 10 iterations)
./scripts/run-tests.sh -b        # Build image (needed first time or after Dockerfile changes)
./scripts/run-tests.sh -n 5      # Run with 5 iterations
./scripts/run-tests.sh -c config.lua  # Use a custom config
./scripts/run-tests.sh -v        # Verbose output
```

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

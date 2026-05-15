# Contributing to Prometheus

Thanks for contributing to Prometheus.

## Requirements

- Keep pull requests focused and small where possible.
- Follow the existing project style and structure.
- Ensure your changes do not break existing tests and behavior.
- Add or update tests when changing behavior.
- Document user-visible changes clearly.

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

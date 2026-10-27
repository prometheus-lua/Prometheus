# Official Lua 5.1 tests

The untouched `vendor/` directory is from the official archive published on
2016-01-18:

- Source: https://www.lua.org/tests/lua5.1-tests.tar.gz
- Archive SHA-256: `49e4ca6561f82ea605908c5041ab5fad66ed9930fa0686675bd51b02767f18ad`
- License: MIT; see `LICENSE` and https://www.lua.org/license.html.

`SHA256SUMS` records every vendored file's checksum. Preparation verifies the
complete file inventory and checksums, then applies `patches/portable.patch`
without fuzz to a fresh artifact working directory. No download is needed to
run tests. `manifest.lua` accounts for all 24 upstream Lua scripts: 18 test
cases, one support module, the replaced launcher, and four excluded cases.

The upstream cases run on Lua 5.1. Existing Prometheus tests continue to run
on both Lua 5.1 and Luau. Each upstream case receives the launcher's locale,
random seed, GC settings, `Message` helper, and module paths. Return-value
checks from `all.lua` and `big.lua`'s coroutine yield/return protocol are
preserved. Cases execute in separate processes and fresh working directories,
so an error or modification of globals cannot prevent later cases from running.

Upstream assertions and successful process completion are the oracle. Timing,
allocation, temporary-name, and address output is retained in failure logs,
but is not compared against the original's stdout. The completion marker is
emitted only after the case and its return-value checks finish. Original and
transformed executions use equivalent environment settings and file layouts.

## Exclusions and coverage boundaries

`exclusions.json` identifies adapted blocks by original file, line range, and
reason. The patch preserves surrounding semantic checks and does not replace
assertions with unconditional successes. Whole-script exclusions are in the
manifest. Debug introspection, exact tail-call stack capacity, original source
names/lines, collector step counts and finalization order, host parser limits,
and native C libraries fall outside this suite's portable scope.

Lua 5.1's legacy implicit `arg` compatibility is unsupported; see
[Limitations](../../../doc/reference/limitations.md). In `vararg.lua`, legacy
table uses are rewritten with `{n = select('#', ...), ...}` and assertions
about the implicit nil `arg` are removed. Argument values, nils, counts,
forwarding, and method-call checks remain covered using explicit varargs.

Replacing a running function's environment is also unsupported, including
`module(...)` calls from transformed code. The affected blocks in `events.lua`,
`attrib.lua`, `locals.lua`, and `nextvar.lua` are adapted or excluded in
`patches/portable.patch` and recorded in `exclusions.json`. Explicit table
metatable and preload checks remain covered. Tests that set a function's
environment before calling it, and thread-default environment checks, stay
enabled; failures of those supported behaviors remain failures.

The native `T` library is absent. Upstream guards therefore also exclude:

- `nextvar.lua`: native table sizes/layout and `T.int2fb` checks;
- `closure.lua`: native yield/hook checks;
- `checktable.lua`: native table-layout inspection; its portable `stat` helper
  is still compiled and transformed when required;
- `locals.lua`: optional `querytab` checks, which the native runtime supplies.

`all.lua` is retained for provenance and replaced by isolated orchestration.
`main.lua` exercises the host interpreter's CLI and interactive input using
newly generated scripts, so it is recorded as excluded. `api.lua`, `code.lua`,
and `db.lua` require native internals or the debug library.

All executable vendored case files and their required Lua support files are
transformed. Source strings and files generated *at runtime* still execute
through the host interpreter's `loadstring`, `load`, `loadfile`, or `require`.
Those tests cover their transformed callers and data construction; they do not
establish Prometheus parser/compiler coverage of the generated source. This is
particularly relevant to `verybig.lua` and the literal/syntax-generation tests.

The historical archive has no `_U` flag. The harness does not enable `_soft`,
which would remove otherwise useful tests. AntiTamper is removed from all
presets, matching the existing suite's convention.

A failure of supported semantics remains a failure. Do not add exclusions
based solely on a failed transformed execution.

## Running and reproducing

From the repository root:

```sh
bash scripts/run-tests.sh -b -n 10 --ci
bash scripts/run-tests.sh --suite upstream --baseline-only --pass-runners
bash scripts/run-tests.sh --suite upstream --case lua51/closure.lua --preset Cff --seed 4 -n 1
```

The same selectors are available directly when `lua5.1`, `luau`, Python 3,
`patch`, and GNU coreutils are installed:

```sh
lua5.1 docker-test-runner.lua --suite=upstream --case=lua51/closure.lua --preset=Cff --seed=4 --iterations=1
lua5.1 tests/harness/metadata.lua
python3 tests/harness/runner.py
```

Every applicable preset, iteration, and runtime is attempted, even after
failures. Only a failed baseline blocks transformed executions for that
case/runtime. Each subprocess has a 30-second limit (overridable with
`--timeout`), including obfuscation. A process that ignores termination is
forcibly killed after five additional seconds. Seeds default to 1 through 10
and are recorded per result.

Artifacts persist under `test-results/run-*` (override with `--artifacts DIR`
in the Docker wrapper or `--artifacts=DIR` directly). Each run contains:

- `run.log`, the complete runner report, and `results.tsv`, one row per execution;
- `adapted/`, the verified and patched upstream source;
- `work/`, failed jobs with pristine `input/`, `generated/` output, isolated
  runtime directories, obfuscation/runtime logs, and `failure-*.txt` metadata.

Successful scratch jobs are removed. Reproduce a failure using the case,
preset, and seed from `results.tsv`, with one iteration. Docker paths under
`/artifacts/` map to the host artifact directory. To replay saved upstream
output directly, enter its `generated-lua5.1/` directory and run:

```sh
lua5.1 case-runner.lua closure.lua none
```

Use the affected file and its `protocol` from the manifest; for example
`big.lua big`, `attrib.lua 27`, or `calls.lua calls`. A baseline uses the
corresponding `input-lua5.1/` directory. An existing case runs as
`lua5.1 case.lua` or `luau case.lua` from its runtime directory.

Docker downloads the current prebuilt Luau release, as before. If a corporate
proxy requires additional trusted certificates, supply a trusted CA bundle as
an optional BuildKit secret; certificate verification remains enabled:

```sh
TEST_CA_BUNDLE=/path/to/trusted-ca-bundle.pem bash scripts/run-tests.sh -b
```

## Updating upstream

Download and verify the official archive checksum before extracting its full
contents to `vendor/`. Regenerate per-file `SHA256SUMS` from those unmodified
files. Review and update patches, exclusions, and the complete manifest; then
verify deterministic preparation, all original baselines, and the full
transformed suite. Keep failing supported tests enabled.

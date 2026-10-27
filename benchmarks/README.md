# Preset benchmarks

Recorded v0.3 measurements: [v0.3-results.md](v0.3-results.md).
Updated Medium measurements: [v0.3-medium-native-cff.md](v0.3-medium-native-cff.md).
Latest VM optimization measurements: [v0.3-vm-fastpaths.md](v0.3-vm-fastpaths.md).

Run from the repository root with Python 3, Lua 5.1, and LuaJIT installed:

```sh
python3 benchmarks/run.py
```

The runner compares original source, Minify, Cff, Vmify, Medium, and Strong.
Production presets retain AntiTamper. Seeds default to 1, 4, and 17, with three
timed batches per generated chunk. Every execution validates a deterministic
checksum against the original source.

The workloads exercise arithmetic and branches, record sorting and aggregation,
string formatting and parsing, and closures with captured state and method
calls. The first chunk argument scales their work; the runner uses scale 1.

Execution measures CPU time for repeated complete chunk invocations after
warmup, excluding parsing. Initialization and allocations in the generated code
are included. Garbage collection runs before each batch and may run during it.
Generation and parsing time are reported separately. Peak memory is not measured.

Reports, raw JSON, and generated sources default to
`test-results/benchmark-v0.3/`. To choose another directory:

```sh
python3 benchmarks/run.py --output /tmp/prometheus-benchmark
```

Other options include `--seeds 1 4 17`, `--samples 3`, `--target 0.1` (target
CPU seconds per batch), `--timeout 60` (seconds per process), and
`--runtimes lua5.1 luajit`. The LuaJIT run leaves JIT enabled. Tiny native JIT
times can produce large slowdown ratios; compare absolute times as well.

Use `--presets Medium` to benchmark a subset of presets against original source.

Use `--resume` with the same output directory and options to reuse completed
measurements after an interrupted run.

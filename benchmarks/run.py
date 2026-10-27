#!/usr/bin/env python3
"""Compare real presets on deterministic workloads; retain inputs and raw metrics."""
import argparse
import json
import platform
from pathlib import Path
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ('Minify', 'Cff', 'Vmify', 'Medium', 'Strong')


def cpu_model():
    cpuinfo = Path('/proc/cpuinfo')
    if cpuinfo.exists():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith('model name'):
                return line.split(':', 1)[1].strip()
    return platform.processor() or 'unknown'


def command(args, timeout):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'{args}:\n{result.stdout}\n{result.stderr}')
    return result.stdout.strip()


def measure(runtime, path, samples, target, timeout):
    fields = {}
    for line in command([runtime, 'benchmarks/measure.lua', str(path),
                         str(samples), str(target)], timeout).splitlines():
        key, value = line.split('\t', 1)
        fields.setdefault(key, []).append(value)
    return dict(checksum=fields['checksum'][0],
                load_seconds=float(fields['load_seconds'][0]),
                repeats=int(fields['repeats'][0]),
                seconds=[float(value) for value in fields['seconds']])


def report(data, output):
    lines = ['# Prometheus v0.3 benchmark', '',
             f"Host: {data['host']}; CPU: {data.get('cpu', cpu_model())}. Runtimes: "
             + '; '.join(data['versions'].values()) + '.', '',
             'Four deterministic workloads compare original source with the actual presets, '
             'including AntiTamper. All variants must match the original checksum.', '',
             f"Seeds: {data['seeds']}; {data['samples']} timed batches per seed. "
             'Each workload is parsed once and warmed up; batches adapt to approximately '
             f"{data['target_seconds']} seconds. Execution includes initialization of the emitted "
             'chunk, workload work, allocations, and checksum validation, but excludes parsing. '
             'Garbage collection runs before each batch; collection during the batch is included.', '',
             'Execution figures are median CPU time per full invocation across batches and seeds. '
             'Generation and parsing figures are medians across seeds. Output size is a median '
             'across seeds. Execution ranges show the lowest and highest per-seed medians. '
             'Measurements are local, with JIT enabled for LuaJIT; very small native '
             'JIT times can produce large slowdown ratios. These workloads do not establish a '
             'general performance guarantee or measure peak memory.', '']
    for runtime in data['versions']:
        lines.extend([f'## {runtime}', '',
                      '| Workload | Preset | Execution ms (median; seed range) | Slowdown | Output KiB | Generate ms | Parse ms |',
                      '| --- | --- | ---: | ---: | ---: | ---: | ---: |'])
        for case in data['cases']:
            rows = [row for row in data['results'] if row['runtime'] == runtime and row['case'] == case]
            baseline = statistics.median(next(row for row in rows if row['preset'] == 'Original')['seconds'])
            for preset in ('Original',) + tuple(data.get('presets', PRESETS)):
                selected = [row for row in rows if row['preset'] == preset]
                seconds = statistics.median([t for row in selected for t in row['seconds']])
                seed_times = [statistics.median(row['seconds']) * 1000 for row in selected]
                execution = f'{seconds * 1000:.3f}'
                if len(selected) > 1:
                    execution += f' ({min(seed_times):.3f}–{max(seed_times):.3f})'
                size = statistics.median(row['bytes'] for row in selected) / 1024
                generation = statistics.median(row['generation_seconds'] for row in selected) * 1000
                load = statistics.median(row['load_seconds'] for row in selected) * 1000
                lines.append(f'| {case} | {preset} | {execution} | {seconds / baseline:.1f}x | '
                             f'{size:.1f} | {generation:.2f} | {load:.2f} |')
        lines.append('')
    (output / 'report.md').write_text('\n'.join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'test-results/benchmark-v0.3')
    parser.add_argument('--seeds', type=int, nargs='+', default=[1, 4, 17])
    parser.add_argument('--samples', type=int, default=3)
    parser.add_argument('--target', type=float, default=0.1)
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--runtimes', nargs='+', default=['lua5.1', 'luajit'])
    parser.add_argument('--presets', nargs='+', choices=PRESETS, default=list(PRESETS))
    parser.add_argument('--resume', action='store_true', help='reuse completed rows in the output directory')
    args = parser.parse_args()
    if args.samples < 1 or args.target <= 0 or args.timeout < 1:
        parser.error('samples, target, and timeout must be positive')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cases = sorted((ROOT / 'benchmarks/cases').glob('*.lua'))
    assert cases, 'No benchmark cases found'
    data = dict(host=platform.platform(), cpu=cpu_model(), seeds=args.seeds, samples=args.samples,
                target_seconds=args.target, cases=[case.stem for case in cases],
                presets=args.presets, versions={}, results=[])
    if args.resume:
        previous = json.loads((output / 'results.json').read_text())
        for key in ('seeds', 'samples', 'target_seconds', 'cases'):
            assert previous[key] == data[key], f'Resume configuration mismatch: {key}'
        assert previous.get('presets', list(PRESETS)) == args.presets, 'Resume preset mismatch'
        data['results'] = previous['results']
    for runtime in args.runtimes:
        version = subprocess.run([runtime, '-v'], text=True, capture_output=True, check=True)
        data['versions'][runtime] = (version.stdout + version.stderr).strip()
    for case in cases:
        generated = [('Original', 0, case, 0.0)]
        for preset in args.presets:
            for seed in args.seeds:
                path = output / f'{case.stem}-{preset}-{seed}.lua'
                completed = next((row for row in data['results'] if row['case'] == case.stem
                                  and row['preset'] == preset and row['seed'] == seed), None)
                if completed and path.exists():
                    elapsed = completed['generation_seconds']
                else:
                    elapsed = float(command(['lua5.1', 'benchmarks/generate.lua', preset,
                                             str(seed), str(case), str(path)], args.timeout))
                generated.append((preset, seed, path, elapsed))
        for runtime in args.runtimes:
            expected = None
            for preset, seed, path, elapsed in generated:
                completed = next((row for row in data['results'] if row['case'] == case.stem
                                  and row['runtime'] == runtime and row['preset'] == preset
                                  and row['seed'] == seed), None)
                row = completed or measure(runtime, path, args.samples, args.target, args.timeout)
                if expected is None:
                    expected = row['checksum']
                assert row['checksum'] == expected, f'Checksum mismatch: {runtime} {path}'
                if completed:
                    continue
                row.update(case=case.stem, runtime=runtime, preset=preset, seed=seed,
                           bytes=path.stat().st_size, generation_seconds=elapsed)
                data['results'].append(row)
                print(f'{runtime} {case.stem} {preset} seed={seed}: '
                      f'{statistics.median(row["seconds"]) * 1000:.3f}ms', flush=True)
                (output / 'results.json').write_text(json.dumps(data, indent=2) + '\n')
    report(data, output)
    print(f'Report: {output / "report.md"}')


if __name__ == '__main__':
    main()

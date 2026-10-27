#!/usr/bin/env python3
"""Exercise subprocess status, selection, continuation, and upstream preparation."""
import csv
import hashlib
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]

def lua(script, *args):
    return subprocess.run(["lua5.1", "-e", script, *map(str, args)], cwd=root,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)

with tempfile.TemporaryDirectory(prefix="prometheus-harness-") as temporary:
    temporary = Path(temporary)
    # The stdout text cannot substitute for a successful exit status.
    status = lua("local l=require('scripts.test.lib'); local out,code=l.run(\"lua5.1 -e 'print(123); os.exit(7)'\",'.',5," +
                 repr(str(temporary / "status.log")) + "); assert(code==7 and out:find('123'))")
    assert status.returncode == 0, status.stdout
    timeout = lua("local l=require('scripts.test.lib'); local _,code=l.run(\"lua5.1 -e 'while true do end'\",'.',1," +
                  repr(str(temporary / "timeout.log")) + "); assert(code==124)")
    assert timeout.returncode == 0, timeout.stdout
    fixtures = temporary / "fixtures"
    fixtures.mkdir()
    (fixtures / "a-error.lua").write_text("print('output before error'); error('expected harness failure')\n")
    (fixtures / "b-timeout.lua").write_text("while true do end\n")
    (fixtures / "c-filter.lua").write_text("-- license\n-- @runtime lua51\n-- @skip_preset BrokenA\nprint('ok')\n")
    (fixtures / "d-skipped.lua").write_text("--[[ license ]]\n-- @skip\nerror('must not run')\n")
    (fixtures / "e-no-runtime.lua").write_text("-- @runtime luajit\nerror('must not run')\n")
    (fixtures / "f-pass.lua").write_text("print('ok')\n")
    config = temporary / "presets.lua"
    config.write_text("return { {Name='BrokenA',LuaVersion='Lua51',Steps={{Name='UnknownHarnessStep'}}}, "
                      "{Name='BrokenB',LuaVersion='Lua51',Steps={{Name='UnknownHarnessStep'}}} }\n")
    run = subprocess.run(["lua5.1", "docker-test-runner.lua", "--suite=existing", "--runtime=lua51",
                          "--iterations=2", "--timeout=1", "--seed=42", f"--test-dir={fixtures}",
                          f"--config={config}", f"--artifacts={temporary / 'artifacts'}"],
                         cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    assert run.returncode == 1, run.stdout
    report = next((temporary / "artifacts").glob("run-*/results.tsv"))
    with report.open() as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    baselines = [r for r in rows if r["phase"] == "baseline"]
    assert len(baselines) == 4, rows
    assert [r["exit_code"] for r in baselines[:2]] == ["1", "124"], rows
    attempts = [r for r in rows if r["phase"] == "transformed"]
    assert len(attempts) == 6, rows  # Two remaining iterations, then both presets of the next case.
    assert {r["seed"] for r in attempts} == {"42", "43"}, rows
    assert not any(r["case"] == "c-filter.lua" and r["preset"] == "BrokenA" for r in attempts), rows
    assert "[SKIP] d-skipped.lua (@skip)" in run.stdout, run.stdout
    assert "[SKIP] e-no-runtime.lua (no matching runtime)" in run.stdout, run.stdout
    assert "f-pass.lua" in attempts[-1]["case"], rows
    for row in attempts:
        artifact = Path(row["artifact"])
        assert (artifact / "input" / row["case"]).is_file(), row
        assert (artifact / f"obfuscate-{row['case']}.log").is_file(), row

    # A successful transformed case preserves comparison behavior and drops scratch files.
    success = subprocess.run(["lua5.1", "docker-test-runner.lua", "--suite=existing", "--runtime=lua5.1",
                              "--case=f-pass.lua", "--preset=Minify", "--iterations=1", f"--test-dir={fixtures}",
                              f"--artifacts={temporary / 'success'}"], cwd=root, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    assert success.returncode == 0, success.stdout
    assert not list((temporary / "success").glob("run-*/work/*"))

    adapted = temporary / "adapted"
    subprocess.run(["python3", "scripts/test/prepare-upstream.py", str(adapted)], cwd=root, check=True,
                   stdout=subprocess.DEVNULL)
    again = temporary / "adapted-again"
    subprocess.run(["python3", "scripts/test/prepare-upstream.py", str(again)], cwd=root, check=True,
                   stdout=subprocess.DEVNULL)
    def digests(directory):
        return {p.relative_to(directory): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in directory.rglob("*") if p.is_file()}
    assert digests(adapted) == digests(again)

    # Support files are transformed, and upstream scripts run from the generated copy.
    support = subprocess.run(["lua5.1", "docker-test-runner.lua", "--suite=upstream", "--case=lua51/big.lua",
                              "--preset=Minify", "--iterations=1", f"--artifacts={temporary / 'support'}"],
                             cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    assert support.returncode == 0, support.stdout

    # A premature os.exit(0) cannot count as an assertion-suite pass.
    (temporary / "premature.lua").write_text("os.exit(0)\n")
    marker = subprocess.run(["lua5.1", str(root / "scripts/test/upstream-case.lua"), "premature.lua", "none"],
                            cwd=temporary, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    assert marker.returncode == 0 and "PROMETHEUS_UPSTREAM_COMPLETE" not in marker.stdout
    (temporary / "protocol.lua").write_text("return 27\n")
    wrong = subprocess.run(["lua5.1", str(root / "scripts/test/upstream-case.lua"), "protocol.lua", "12"],
                           cwd=temporary, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    assert wrong.returncode != 0 and "PROMETHEUS_UPSTREAM_COMPLETE" not in wrong.stdout

print("Runner regression checks passed")

-- Baselines and transformed cases run in isolated, timed subprocesses.
local lib = require("scripts.test.lib")
local metadata = require("scripts.test.metadata")
local presets = require("src.presets")
local args = {}
for _, a in ipairs(arg) do
    local key, value = a:match("^%-%-([%w_%-]+)=(.*)$")
    if key then args[key] = value
    else
        key = a:match("^%-%-([%w_%-]+)$")
        assert(key, "invalid argument " .. a)
        args[key] = true
    end
end
local function integer(key, default)
    local value = tonumber(args[key] or default)
    assert(value and value >= 1 and value == math.floor(value), "--" .. key .. " must be a positive integer")
    return value
end
local iterations, timeout, seed = integer("iterations", 10), integer("timeout", 60), integer("seed", 1)
assert(seed + iterations - 1 <= 2147483647, "seed range must fit a signed 32-bit integer")
local suite = args.suite or "all"
assert(suite == "all" or suite == "existing" or suite == "upstream", "invalid --suite")
local cwd_handle = assert(io.popen("pwd"))
local root = assert(cwd_handle:read("*l"))
cwd_handle:close()
local function absolute(path)
    return path:sub(1, 1) == "/" and path or root .. "/" .. path
end
local artifact_parent = absolute(args.artifacts or "test-results")
lib.mkdir(artifact_parent)
local artifacts = lib.tempdir(artifact_parent, "run-" .. os.date("!%Y%m%d-%H%M%S"))
lib.mkdir(artifacts .. "/work")
local report = assert(io.open(artifacts .. "/run.log", "w"))
io.stdout:setvbuf("no")
local function say(message)
    print(message)
    report:write(message .. "\n")
    report:flush()
end
local results = assert(io.open(artifacts .. "/results.tsv", "w"))
results:write("case\tphase\tpreset\titeration\truntime\tseed\tstatus\texit_code\tartifact\n")
local totals = { passed = 0, failed = 0, baseline_passed = 0, baseline_failed = 0, timeouts = 0, excluded = 0, skipped = 0 }
local function record(case, phase, preset, iteration, runtime, run_seed, status, exit_code, path)
    results:write(table.concat({case, phase, preset, iteration, runtime, run_seed, status, exit_code, path}, "\t") .. "\n")
    results:flush()
    local counter = phase == "baseline" and (status == "PASS" and "baseline_passed" or "baseline_failed") or
        (status == "PASS" and "passed" or "failed")
    totals[counter] = totals[counter] + 1
    if exit_code == 124 or exit_code == 137 then totals.timeouts = totals.timeouts + 1 end
end

local runtimes = { { name = "lua5.1", cmd = "lua5.1" }, { name = "luau", cmd = "luau" } }
if args.runtime == "lua51" then args.runtime = "lua5.1" end
assert(not args.runtime or args.runtime == "lua5.1" or args.runtime == "luau", "invalid --runtime")
local configs = {}
local config_path = args.config and absolute(args.config) or ""
if args.config then
    local loaded = assert(loadfile(config_path))()
    if type(loaded[1]) == "table" then
        for i, cfg in ipairs(loaded) do configs[#configs + 1] = { name = cfg.Name or ("custom-" .. i), selector = tostring(i) } end
    else configs[1] = { name = loaded.Name or "custom", selector = "1" } end
else
    for name in pairs(presets) do configs[#configs + 1] = { name = name, selector = name } end
    table.sort(configs, function(a, b) return a.name < b.name end)
end
if args.preset then
    local selected = {}
    for _, cfg in ipairs(configs) do if cfg.name == args.preset then selected[#selected + 1] = cfg end end
    assert(#selected > 0, "unknown --preset " .. args.preset)
    configs = selected
end

say("=== Prometheus Test Runner ===")
say("Iterations: " .. iterations .. "; seeds: " .. seed .. ".." .. (seed + iterations - 1) .. "; timeout: " .. timeout .. "s")
say("Suite: " .. suite .. "; AntiTamper removed from presets")
say("Artifacts: " .. artifacts)
local cases = {}
if suite ~= "upstream" then
    local directory = absolute(args["test-dir"] or "tests")
    for _, file in ipairs(lib.files(directory)) do
        cases[#cases + 1] = { name = file, file = file, directory = directory, supports = {} }
    end
end
if suite ~= "existing" then
    local upstream = root .. "/tests/upstream/lua51"
    local manifest = assert(loadfile(upstream .. "/manifest.lua"))()
    local seen = {}
    for _, entry in ipairs(manifest) do
        assert(not seen[entry.file], "duplicate upstream manifest entry " .. entry.file)
        seen[entry.file] = entry
        assert(entry.role == "case" or entry.role == "support" or entry.role == "launcher" or entry.role == "excluded", "invalid upstream role")
    end
    local files = lib.files(upstream .. "/vendor")
    assert(#files == #manifest, "upstream manifest must account for every Lua script")
    for _, file in ipairs(files) do assert(seen[file], "unaccounted upstream script " .. file) end
    local output, status = lib.run("python3 scripts/test/prepare-upstream.py " .. lib.quote(artifacts .. "/adapted"), root, timeout, artifacts .. "/prepare.log")
    assert(status == 0, "upstream preparation failed: " .. output)
    for _, entry in ipairs(manifest) do
        if entry.role == "case" then
            local supports = entry.supports or {}
            for _, support in ipairs(supports) do assert(seen[support] and seen[support].role == "support", "invalid support file " .. support) end
            cases[#cases + 1] = { name = "lua51/" .. entry.file, file = entry.file, directory = artifacts .. "/adapted",
                upstream = true, protocol = entry.protocol, supports = supports }
        elseif entry.role ~= "support" then
            totals.excluded = totals.excluded + 1
            say("[EXCLUDED] lua51/" .. entry.file .. ": " .. entry.reason)
        end
    end
end
if args.case then
    local selected = {}
    for _, case in ipairs(cases) do if case.name == args.case then selected[#selected + 1] = case end end
    assert(#selected > 0, "unknown --case " .. args.case)
    cases = selected
end

local function new_job(case, label)
    local safe = (case.name .. "-" .. label):gsub("[^%w._%-]", "_")
    local path = lib.tempdir(artifacts .. "/work", safe)
    lib.mkdir(path .. "/input")
    lib.mkdir(path .. "/generated")
    lib.write(path .. "/input/" .. case.file, lib.read(case.directory .. "/" .. case.file))
    for _, support in ipairs(case.supports) do
        lib.write(path .. "/input/" .. support, lib.read(case.directory .. "/" .. support))
    end
    return path
end
local function stage(case, directory)
    lib.mkdir(directory .. "/libs/P1")
    if case.upstream then lib.write(directory .. "/case-runner.lua", lib.read(root .. "/scripts/test/upstream-case.lua")) end
end
local function execute(case, runtime, directory, log)
    local runtime_directory = directory .. "-" .. runtime.name
    lib.mkdir(runtime_directory)
    lib.write(runtime_directory .. "/" .. case.file, lib.read(directory .. "/" .. case.file))
    for _, support in ipairs(case.supports) do
        lib.write(runtime_directory .. "/" .. support, lib.read(directory .. "/" .. support))
    end
    stage(case, runtime_directory)
    local command = runtime.cmd .. " " .. lib.quote(case.file)
    if case.upstream then
        command = runtime.cmd .. " case-runner.lua " .. lib.quote(case.file) .. " " .. lib.quote(case.protocol)
    end
    local output, code = lib.run(command, runtime_directory, timeout, log)
    if code ~= 0 then return output, code, "exit " .. code end
    if case.upstream and not output:find("\nPROMETHEUS_UPSTREAM_COMPLETE\n", 1, true) then
        return output, code, "missing completion marker"
    end
    return output, code
end
local function clean(path)
    -- Only remove fresh, runner-owned work directories; retain every failed job.
    assert(path:sub(1, #artifacts + 6) == artifacts .. "/work/")
    assert(lib.status(os.execute("rm -rf -- " .. lib.quote(path))) == 0)
end
local function failure(case, phase, cfg, iter, runtime, run_seed, output, code, reason, path)
    lib.write(path .. "/failure-" .. runtime .. ".txt", reason .. "\ncase=" .. case.name .. "\npreset=" .. cfg .. "\niteration=" .. iter ..
        "\nruntime=" .. runtime .. "\nseed=" .. run_seed .. "\n")
    record(case.name, phase, cfg, iter, runtime, run_seed, "FAIL", code, path)
    say("[" .. (phase == "baseline" and "BASELINE FAIL" or "FAIL") .. "] " .. case.name .. " " .. cfg .. " #" .. iter ..
        " on " .. runtime .. " seed=" .. run_seed .. ": " .. reason .. " (" .. path .. ")")
    say(output:sub(1, 500))
end

for _, case in ipairs(cases) do
    local parsed, meta = pcall(metadata.parse, lib.read(case.directory .. "/" .. case.file), case.name)
    if not parsed then
        totals.failed = totals.failed + 1
        say("[METADATA FAIL] " .. meta)
    elseif meta.skip then
        totals.skipped = totals.skipped + 1
        say("[SKIP] " .. case.name .. " (@skip)")
    else
        local active, baselines = {}, {}
        for _, runtime in ipairs(runtimes) do
            if (not args.runtime or args.runtime == runtime.name) and (not case.upstream or runtime.name == "lua5.1") and
                (not next(meta.runtimes) or meta.runtimes[runtime.name]) then active[#active + 1] = runtime end
        end
        if #active == 0 then
            totals.skipped = totals.skipped + 1
            say("[SKIP] " .. case.name .. " (no matching runtime)")
        else
            say("[TEST] " .. case.name)
            for _, runtime in ipairs(active) do
                local path = new_job(case, "baseline-" .. runtime.name)
                local output, code, reason = execute(case, runtime, path .. "/input", path .. "/output.log")
                if reason then failure(case, "baseline", "-", 0, runtime.name, 0, output, code, reason, path)
                else
                    baselines[runtime.name] = output
                    record(case.name, "baseline", "-", 0, runtime.name, 0, "PASS", 0, "-")
                    if args["pass-runners"] or args.verbose then say("[BASELINE PASS] " .. case.name .. " on " .. runtime.name) end
                    clean(path)
                end
            end
            if not args["baseline-only"] and next(baselines) then
                for _, cfg in ipairs(configs) do
                    if meta.skip_presets[cfg.name] then
                        totals.skipped = totals.skipped + 1
                        say("[SKIP] " .. case.name .. " preset " .. cfg.name)
                    else
                        local passed = true
                        for iter = 1, iterations do
                            local run_seed = seed + iter - 1
                            local path = new_job(case, cfg.name .. "-" .. iter)
                            local files = {case.file}
                            for _, support in ipairs(case.supports) do files[#files + 1] = support end
                            local transform_error, transform_output, transform_code
                            for _, file in ipairs(files) do
                                local command = "lua5.1 scripts/test/obfuscate.lua " .. lib.quote(config_path) .. " " .. lib.quote(cfg.selector) ..
                                    " " .. run_seed .. " " .. lib.quote(path .. "/input/" .. file) .. " " .. lib.quote(path .. "/generated/" .. file)
                                local output, code = lib.run(command, root, timeout, path .. "/obfuscate-" .. file .. ".log")
                                if code ~= 0 then
                                    transform_error, transform_output, transform_code = "obfuscation of " .. file .. " exited " .. code, output, code
                                    break
                                end
                            end
                            local failed = false
                            for _, runtime in ipairs(active) do
                                if baselines[runtime.name] then
                                    local output, code, reason
                                    if transform_error then output, code, reason = transform_output, transform_code, transform_error
                                    else
                                        output, code, reason = execute(case, runtime, path .. "/generated", path .. "/" .. runtime.name .. ".log")
                                        if not reason and not case.upstream and lib.normalize(output) ~= lib.normalize(baselines[runtime.name]) then
                                            reason = "output mismatch"
                                            lib.write(path .. "/expected-" .. runtime.name .. ".log", baselines[runtime.name])
                                        end
                                    end
                                    if reason then
                                        failed, passed = true, false
                                        failure(case, "transformed", cfg.name, iter, runtime.name, run_seed, output, code, reason, path)
                                    else record(case.name, "transformed", cfg.name, iter, runtime.name, run_seed, "PASS", 0, "-") end
                                end
                            end
                            if not failed then clean(path) end
                        end
                        if passed then say("[PASS] " .. case.name .. " " .. cfg.name .. " (" .. iterations .. " iterations)") end
                    end
                end
            end
        end
    end
end
say(string.format("Total: %d transformed passed, %d failed; %d baselines passed, %d failed; %d timeouts; %d scripts excluded; %d selections skipped",
    totals.passed, totals.failed, totals.baseline_passed, totals.baseline_failed, totals.timeouts, totals.excluded, totals.skipped))
results:close()
report:close()
os.exit(totals.failed + totals.baseline_failed == 0 and 0 or 1)

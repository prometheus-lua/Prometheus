-- docker-test-runner.lua
-- Docker-based test orchestrator for Prometheus
-- Runs each test script against all Lua runtimes and presets, comparing output

local Prometheus = require("src.prometheus")
local Presets = require("src.presets")

-- === Argument Parsing ===
local args = {}
for _, a in ipairs(arg) do
    local key, val = a:match("^%-%-([%w_]+)=(.+)$")
    if key then
        args[key] = val
    elseif a:match("^%-%-([%w_]+)$") then
        args[a:match("^%-%-(.+)$")] = true
    end
end

local ITERATIONS = math.max(tonumber(args.iterations) or 10, 1)
local CUSTOM_CONFIG = args.config
local CI_MODE = args.CI == true or args.ci == true
local TEST_DIR = "./tests/"
local PASS_RUNNERS = (args["pass-runners"] ~= nil)
local VERBOSE = args.verbose == true

-- === Runtimes ===
local RUNTIMES = {
    {
        name = "lua5.1",
        cmd = "lua5.1",
    },
    {
        name = "luau",
        cmd = "luau",
    },
}

-- === Helpers ===
local function shell_escape(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function exec(cmd)
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        return nil, "failed to execute: " .. cmd
    end
    local output = handle:read("*a")
    local ok = handle:close()
    -- In Lua 5.1, popen:close() returns true for zero exit, nil otherwise
    -- In LuaJIT/Lua 5.2+, returns true/nil with additional status info
    if ok then
        return output, 0
    else
        return output, 1
    end
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_output(s)
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    for line in s:gmatch("[^\n]*") do
        table.insert(lines, trim(line))
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    return table.concat(lines, "\n")
end

local colors = {
    red     = "\27[31m",
    green   = "\27[32m",
    yellow  = "\27[33m",
    magenta = "\27[35m",
    cyan    = "\27[36m",
    reset   = "\27[0m",
    bold    = "\27[1m",
}
local function fmt(col, text)
    return (colors[col] or "") .. text .. colors.reset
end

-- === Metadata parsing ===
-- Test files can have metadata comments at the top:
--   -- @skip (skip this test entirely)
--   -- @luau-only (only run with luau)
--   -- @runtime lua51 luajit (only run with specified runtimes)
--   -- @skip-preset Weak (skip a specific preset)
local function parse_metadata(code)
    local meta = {
        runtimes = {},
        skip_presets = {},
        skip = false,
    }
    for line in code:gmatch("[^\n]*") do
        if not line:match("^%s*%-%-%s*@") then
            break
        end
        local key, val = line:match("^%s*%-%-%s*@(%w+)%s+(.+)")
        if key then
            if key == "runtime" then
                for r in val:gmatch("%S+") do
                    meta.runtimes[r:lower()] = true
                end
            elseif key == "skip_preset" or key == "skip-preset" then
                meta.skip_presets[val] = true
            elseif key == "luau_only" or key == "luau-only" then
                meta.runtimes["luau"] = true
            end
        end
        if line:match("^%s*%-%-%s*@skip%s*$") then
            meta.skip = true
        end
        if line:match("^%s*%-%-%s*@luau%-only%s*$") then
            meta.runtimes["luau"] = true
        end
    end
    return meta
end

-- === Baseline capture ===
local function run_script(runtime, script_path)
    local out, status = exec(runtime.cmd .. " " .. shell_escape(script_path))
    if status ~= 0 then
        return nil, "exit code " .. tostring(status) .. ": " .. (out or "")
    end
    return normalize_output(out), nil
end

-- === List test files ===
local function scandir(dir)
    local handle = io.popen("ls -1 " .. shell_escape(dir))
    if not handle then
        error("Failed to list directory: " .. dir)
    end
    local files = {}
    for name in handle:lines() do
        if name:match("%.lua$") then
            table.insert(files, name)
        end
    end
    handle:close()
    table.sort(files)
    return files
end

-- === Shallow copy ===
local function shallowcopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

-- === Test a single runfile against a single test file ===
-- Returns true if passed, false if failed
local function test_runfile(filename, code, meta, runfile, active_runtimes, baselines)
    local runfile_name = runfile._name

    -- Check for skip-preset
    if meta.skip_presets[runfile_name] then
        print("  " .. fmt("yellow", "[SKIP]") .. " preset " .. runfile_name)
        return true
    end

    for iter = 1, ITERATIONS do
        -- Remove AntiTamper step before testing
        local steps = {}
        for _, step in ipairs(runfile.Steps) do
            if step.Name ~= "AntiTamper" then
                table.insert(steps, shallowcopy(step))
            end
        end
        local cfg = shallowcopy(runfile)
        cfg.Steps = steps

        local pipeline = Prometheus.Pipeline:fromConfig(cfg)
        pipeline:setNameGenerator("MangledShuffled")

        local ok, obfuscated = pcall(pipeline.apply, pipeline, code)
        if not ok then
            local err_msg = "obfuscation error: " .. tostring(obfuscated)
            print("  " .. fmt("red", "[FAIL] ") .. runfile_name .. " #" .. iter .. " - " .. fmt("red", err_msg))
            if type(obfuscated) == "string" and #obfuscated > 200 then
                print("    " .. obfuscated:sub(1, 200) .. "...")
            end
            return false
        end

        -- Write obfuscated code to a temp file
        local tmpfile = "/tmp/prometheus_test_obfuscated.lua"
        local tfh = io.open(tmpfile, "w")
        if not tfh then
            print("  " .. fmt("red", "[FAIL] ") .. runfile_name .. " #" .. iter .. " - cannot write temp file")
            return false
        end
        tfh:write(obfuscated)
        tfh:close()

        -- Run against each active runtime
        for _, rt in ipairs(active_runtimes) do
            local out, err = run_script(rt, tmpfile)
            if err then
                print("  " .. fmt("red", "[FAIL] ") .. runfile_name .. " #" .. iter .. " on " .. rt.name .. fmt("red", " - error"))
                print("    " .. fmt("yellow", "[ERR] ") .. err:sub(1, 300))
                print("    " .. fmt("yellow", "[SRC] ") .. obfuscated:gsub("\n", "\\n"):sub(1, 300))
                os.remove(tmpfile)
                return false
            end

            local expected = baselines[rt.name]
            if normalize_output(out) ~= normalize_output(expected) then
                print("  " .. fmt("red", "[FAIL] ") .. runfile_name .. " #" .. iter .. " on " .. rt.name .. " - output mismatch")
                local max_show = 300
                print("    " .. fmt("yellow", "[EXPECTED] ") .. expected:sub(1, max_show))
                print("    " .. fmt("yellow", "[GOT]     ") .. out:sub(1, max_show))
                os.remove(tmpfile)
                return false
            end
        end

        os.remove(tmpfile)
    end

    local runtime_list = {}
    for _, rt in ipairs(active_runtimes) do
        table.insert(runtime_list, rt.name)
    end
    local n_runtimes = #active_runtimes
    print(string.format("  " .. fmt("green", "[PASS]") .. " %s (%d iterations on %s)", runfile_name, ITERATIONS, table.concat(runtime_list, ", ")))
    return true
end

-- === Main ===

-- Determine which presets/runfiles to use
local runfiles = {}
if CUSTOM_CONFIG then
    local cfg, err = loadfile(CUSTOM_CONFIG)
    if not cfg then
        error("Failed to load custom config: " .. tostring(err))
    end
    local loaded = cfg()
    if type(loaded[1]) == "table" then
        for i, c in ipairs(loaded) do
            c._name = c.Name or ("custom-" .. i)
            table.insert(runfiles, c)
        end
    else
        loaded._name = loaded.Name or "custom"
        table.insert(runfiles, loaded)
    end
else
    for name, preset in pairs(Presets) do
        local copy = shallowcopy(preset)
        copy._name = name
        table.insert(runfiles, copy)
    end
    table.sort(runfiles, function(a, b) return a._name < b._name end)
end

-- Suppress Prometheus logger output during tests
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

print(fmt("bold", "=== Prometheus Docker Test Runner ==="))
print(string.format("Test files:  %s", TEST_DIR))
print(string.format("Iterations:  %d", ITERATIONS))
print(string.format("Preset(s):   %s", CUSTOM_CONFIG and "custom (" .. CUSTOM_CONFIG .. ")" or "all built-in"))
print(string.format("CI mode:     %s", CI_MODE and "yes" or "no"))
print("")

local test_files = scandir(TEST_DIR)
local total_passed = 0
local total_failed = 0

for _, filename in ipairs(test_files) do
    local filepath = TEST_DIR .. filename
    local fh = io.open(filepath, "r")
    if not fh then
        print(fmt("red", "[ERROR] ") .. "cannot open " .. filepath)
        total_failed = total_failed + 1
    else
        local code = fh:read("*a")
        fh:close()

        local meta = parse_metadata(code)
        if meta.skip then
            print(fmt("yellow", "[SKIP] ") .. filename .. " (marked @skip)")
        else
            -- Determine active runtimes
            local active_runtimes = {}
            local has_runtime_filter = next(meta.runtimes) ~= nil
            for _, rt in ipairs(RUNTIMES) do
                if has_runtime_filter then
                    if meta.runtimes[rt.name] then
                        table.insert(active_runtimes, rt)
                    end
                else
                    table.insert(active_runtimes, rt)
                end
            end

            if #active_runtimes == 0 then
                print(fmt("yellow", "[SKIP] ") .. filename .. " (no matching runtimes)")
            else
                -- Get baselines
                local baselines = {}
                local baseline_ok = true
                for _, rt in ipairs(active_runtimes) do
                    local out, err = run_script(rt, filepath)
                    if err then
                        print(fmt("red", "[BASELINE FAIL] ") .. filename .. " on " .. rt.name .. ": " .. err)
                        baseline_ok = false
                        break
                    end
                    if PASS_RUNNERS then
                        print(string.format("  " .. fmt("green", "[BASELINE] ") .. "%s on %s PASSED", filename, rt.name))
                    end
                    baselines[rt.name] = out
                end

                if not baseline_ok then
                    total_failed = total_failed + 1
                else
                    print(fmt("magenta", "[TEST] ") .. filename)

                    local file_failed = false
                    for _, runfile in ipairs(runfiles) do
                        if not test_runfile(filename, code, meta, runfile, active_runtimes, baselines) then
                            file_failed = true
                            break
                        end
                    end

                    if file_failed then
                        total_failed = total_failed + 1
                    else
                        total_passed = total_passed + 1
                    end
                end
            end
        end
    end
end

print("")
local total = total_passed + total_failed
print(string.format("Total: %d passed, %d failed, %d total", total_passed, total_failed, total))

if total_failed == 0 then
    print(fmt("green", fmt("bold", "=== ALL TESTS PASSED ===")))
    os.exit(0)
else
    print(fmt("red", fmt("bold", string.format("=== %d TEST(S) FAILED ===", total_failed))))
    os.exit(1)
end

import glueWasmUrl from "wasmoon/dist/glue.wasm?url"

import luaSources from "virtual:prometheus-lua"
import type { PrometheusLog, PrometheusOptions, PrometheusResult } from "@/lib/prometheusTypes"
import { toLuaLongString } from "./luaString"

type LuaFactoryConstructor = new (
  customWasmUri?: string,
  environmentVariables?: Record<string, string>,
) => {
  createEngine(options?: { openStandardLibs?: boolean }): Promise<{
    doString(luaCode: string): Promise<unknown>
    global: { close(): void }
  }>
}

let luaFactoryCtorPromise: Promise<LuaFactoryConstructor> | null = null

async function getLuaFactoryConstructor(): Promise<LuaFactoryConstructor> {
  if (luaFactoryCtorPromise) {
    return luaFactoryCtorPromise
  }

  luaFactoryCtorPromise = import("wasmoon/dist/index.js").then((mod) => {
    const globalCandidate = (globalThis as { wasmoon?: { LuaFactory?: unknown } }).wasmoon?.LuaFactory
    const moduleCandidate = (mod as { LuaFactory?: unknown }).LuaFactory
    const defaultCandidate = (mod as { default?: { LuaFactory?: unknown } }).default?.LuaFactory
    const candidate = (globalCandidate ?? moduleCandidate ?? defaultCandidate) as LuaFactoryConstructor | undefined

    if (typeof candidate !== "function") {
      throw new Error("Unable to resolve LuaFactory export from wasmoon.")
    }

    return candidate
  })

  return luaFactoryCtorPromise
}

const bootstrapLua = Object.entries(luaSources)
  .map(([name, source]) => {
    const chunkName = `@/src/${name.split(".").join("/")}.lua`
    return `
package.preload[ ${toLuaLongString(name)} ] = function(...)
  local chunk, err = load(${toLuaLongString(source)}, ${toLuaLongString(chunkName)}, "t")
  if not chunk then
    error(err)
  end
  return chunk(...)
end`
  })
  .join("\n")

export function buildRunLua(options: PrometheusOptions): string {
  return `
_G.arg = _G.arg or {}
${bootstrapLua}

local logs = {}
local unpackFn = table.unpack or unpack
local function pushLog(level, ...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(i, ...))
  end
  if type(_G.__prometheusPushLog) == "function" then
    _G.__prometheusPushLog(level, unpackFn(parts))
  end
  logs[#logs + 1] = { level = level, message = table.concat(parts, " ") }
end

if not math.log10 then
  math.log10 = function(value)
    return math.log(value, 10)
  end
end

local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info
Prometheus.colors.enabled = false
Prometheus.Logger.debugCallback = function(...) pushLog("debug", ...) end
Prometheus.Logger.logCallback = function(...) pushLog("info", ...) end
Prometheus.Logger.warnCallback = function(...) pushLog("warn", ...) end
Prometheus.Logger.errorCallback = function(...)
  pushLog("error", ...)
  error(table.concat((function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    return parts
  end)(...), " "))
end

local ok, outputOrError = xpcall(function()
  local preset = ${toLuaLongString(options.preset)}
  local source = ${toLuaLongString(options.source)}
  local filename = ${toLuaLongString(options.filename)}
  local config = {}
  for key, value in pairs(Prometheus.Presets[preset]) do
    config[key] = value
  end

  config.LuaVersion = ${toLuaLongString(options.luaVersion)}
  config.PrettyPrint = ${options.prettyPrint ? "true" : "false"}
  config.Seed = ${Math.max(1, Math.floor(options.seed))}

  return Prometheus.Pipeline:fromConfig(config):apply(source, filename)
end, debug.traceback)

return { ok = ok, output = ok and outputOrError or "", error = ok and "" or outputOrError, logs = logs }
`
}

interface LuaScriptOptions {
  source: string
  filename: string
}

export function buildScriptRunLua(options: LuaScriptOptions): string {
  return `
local logs = {}
local unpackFn = table.unpack or unpack
local function pushLog(level, ...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(i, ...))
  end
  if type(_G.__prometheusPushLog) == "function" then
    _G.__prometheusPushLog(level, unpackFn(parts))
  end
  logs[#logs + 1] = { level = level, message = table.concat(parts, " ") }
end

print = function(...)
  pushLog("info", ...)
end

local ok, err = xpcall(function()
  local chunk, loadErr = load(${toLuaLongString(options.source)}, ${toLuaLongString(options.filename)}, "t")
  if not chunk then
    error(loadErr)
  end
  chunk()
end, debug.traceback)

if not ok then
  pushLog("error", err)
end

return { ok = ok, output = "", error = ok and "" or err, logs = logs }
`
}

function normalizeLogs(logs: unknown): PrometheusLog[] {
  if (!Array.isArray(logs)) {
    return []
  }

  return logs.map((entry) => {
    const candidate = entry as { level?: unknown; message?: unknown }
    return {
      level: candidate.level === "warn" || candidate.level === "error" || candidate.level === "debug" ? candidate.level : "info",
      message: String(candidate.message ?? ""),
    }
  })
}

export async function runPrometheus(options: PrometheusOptions): Promise<PrometheusResult> {
  const logs: PrometheusLog[] = []
  let lua: Awaited<ReturnType<InstanceType<LuaFactoryConstructor>["createEngine"]>> | null = null

  try {
    // Force a local Vite-managed Wasm URL so dev/preview behave the same and
    // we don't depend on wasmoon's default CDN URL resolution in workers.
    const LuaFactory = await getLuaFactoryConstructor()
    lua = await new LuaFactory(glueWasmUrl).createEngine({ openStandardLibs: true })

    const result = (await lua.doString(buildRunLua(options))) as {
      ok?: unknown
      output?: unknown
      error?: unknown
      logs?: unknown
    }
    if (result.ok === false) {
      return {
        ok: false,
        error: String(result.error ?? "Prometheus failed"),
        logs: normalizeLogs(result.logs),
      }
    }

    return { ok: true, output: String(result.output ?? ""), logs: normalizeLogs(result.logs) }
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      logs,
    }
  } finally {
    lua?.global.close()
  }
}

export async function runLuaScript(
  options: LuaScriptOptions,
  onLog?: (log: PrometheusLog) => void,
): Promise<PrometheusResult> {
  let lua: Awaited<ReturnType<InstanceType<LuaFactoryConstructor>["createEngine"]>> | null = null

  try {
    const LuaFactory = await getLuaFactoryConstructor()
    lua = await new LuaFactory(glueWasmUrl).createEngine({ openStandardLibs: true })
    if (onLog) {
      const luaGlobal = lua.global as unknown as {
        set?: (name: string, value: (...args: unknown[]) => void) => void
      }
      luaGlobal.set?.("__prometheusPushLog", (level: unknown, ...parts: unknown[]) => {
        const normalized: PrometheusLog = {
          level: level === "warn" || level === "error" || level === "debug" ? level : "info",
          message: parts.map((part) => String(part)).join(" "),
        }
        onLog(normalized)
      })
    }

    const result = (await lua.doString(buildScriptRunLua(options))) as {
      ok?: unknown
      output?: unknown
      error?: unknown
      logs?: unknown
    }
    if (result.ok === false) {
      return {
        ok: false,
        error: String(result.error ?? "Script execution failed"),
        logs: normalizeLogs(result.logs),
      }
    }

    return { ok: true, output: String(result.output ?? ""), logs: normalizeLogs(result.logs) }
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      logs: [],
    }
  } finally {
    lua?.global.close()
  }
}

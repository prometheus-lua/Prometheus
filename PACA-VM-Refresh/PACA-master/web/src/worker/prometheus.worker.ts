import type { WorkerRequest, WorkerResponse } from "@/lib/prometheusTypes"
type RunPrometheus = typeof import("./prometheusRunner")["runPrometheus"]
type RunLuaScript = typeof import("./prometheusRunner")["runLuaScript"]

let runPrometheus: RunPrometheus | null = null
let runLuaScript: RunLuaScript | null = null

async function loadRunner() {
  const module = await import("./prometheusRunner")
  runPrometheus ??= module.runPrometheus
  runLuaScript ??= module.runLuaScript
  return { runPrometheus, runLuaScript }
}

self.onmessage = async (event: MessageEvent<WorkerRequest>) => {
  const request = event.data

  const result = await loadRunner()
    .then(({ runPrometheus: doObfuscate, runLuaScript: doRun }) => {
      if (request.action === "obfuscate") {
        return doObfuscate(request.options)
      }

      return doRun(
        { source: request.source, filename: request.filename },
        (log) => {
          const logResponse: WorkerResponse = { id: request.id, type: "log", log }
          self.postMessage(logResponse)
        },
      )
    })
    .catch((error) => ({
      ok: false as const,
      error:
        error instanceof Error
          ? `${error.name}: ${error.message}${error.stack ? `\n${error.stack}` : ""}`
          : String(error),
      logs: [],
    }))

  const response: WorkerResponse = { id: request.id, type: "result", result }
  self.postMessage(response)
}

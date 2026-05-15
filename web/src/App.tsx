import { BookText, Check, Copy, Download, FileCode2, Github, Loader2, Play, RotateCcw, Share2, Square } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { toast } from "sonner"

import { CodeEditor } from "@/components/CodeEditor"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { Toaster } from "@/components/ui/sonner"
import { Switch } from "@/components/ui/switch"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import {
  LUA_VERSIONS,
  PRESETS,
  type LuaVersion,
  type PresetName,
  type PrometheusLog,
  type PrometheusResult,
  type WorkerRequest,
  type WorkerResponse,
} from "@/lib/prometheusTypes"

const initialSource = `local message = "Hello, World!"
print(message)
`
const WORKER_TIMEOUT_MS = 90_000

type ActiveJob = "idle" | "obfuscate" | "run-input" | "run-output"
type SharePayload = {
  version: 1
  source: string
  preset: PresetName
  luaVersion: LuaVersion
  prettyPrint: boolean
  seed: number
  outputHash: string | null
}
type LastObfuscation = Omit<SharePayload, "version">

function createSeed() {
  return Math.floor(crypto.getRandomValues(new Uint32Array(1))[0] % 2147483646) + 1
}

function downloadLua(output: string) {
  const blob = new Blob([output], { type: "text/x-lua;charset=utf-8" })
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = "prometheus.obfuscated.lua"
  link.click()
  URL.revokeObjectURL(url)
}

function formatWorkerError(event: ErrorEvent): string {
  const location =
    event.filename && event.lineno
      ? ` (${event.filename}:${event.lineno}:${event.colno})`
      : ""
  const detail =
    event.error instanceof Error
      ? `${event.error.name}: ${event.error.message}${event.error.stack ? `\n${event.error.stack}` : ""}`
      : event.message || "Worker crashed while processing the request."
  return `${detail}${location}`
}

function encodeBase64Url(input: string): string {
  const bytes = new TextEncoder().encode(input)
  let binary = ""
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function decodeBase64Url(input: string): string {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/")
  const padding = "=".repeat((4 - (normalized.length % 4)) % 4)
  const binary = atob(normalized + padding)
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0))
  return new TextDecoder().decode(bytes)
}

function fallbackHash(input: string): string {
  // FNV-1a 32-bit fallback for environments where SubtleCrypto is unavailable.
  let hash = 0x811c9dc5
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193)
  }
  return `fnv1a32:${(hash >>> 0).toString(16).padStart(8, "0")}`
}

async function sha256Hex(input: string): Promise<string> {
  if (!crypto.subtle) {
    return fallbackHash(input)
  }
  const bytes = new TextEncoder().encode(input)
  const digest = await crypto.subtle.digest("SHA-256", bytes)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("")
}

export default function App() {
  const [source, setSource] = useState(initialSource)
  const [output, setOutput] = useState("")
  const [preset, setPreset] = useState<PresetName>("Medium")
  const [luaVersion, setLuaVersion] = useState<LuaVersion>("Lua51")
  const [prettyPrint, setPrettyPrint] = useState(false)
  const [seed, setSeed] = useState(createSeed)
  const [logs, setLogs] = useState<PrometheusLog[]>([])
  const [activeJob, setActiveJob] = useState<ActiveJob>("idle")
  const [copied, setCopied] = useState(false)
  const [lastObfuscation, setLastObfuscation] = useState<LastObfuscation | null>(null)
  const workerRef = useRef<Worker | null>(null)
  const requestIdRef = useRef(0)
  const workerUrlRef = useRef<string>("")
  const autoShareLoadedRef = useRef(false)
  const pendingWorkerRejectsRef = useRef(new Set<(error: Error) => void>())

  function rejectPendingWorkerRequests(message: string) {
    for (const reject of pendingWorkerRejectsRef.current) {
      reject(new Error(message))
    }
    pendingWorkerRejectsRef.current.clear()
  }

  function setupWorker(worker: Worker) {
    worker.addEventListener("error", (event: Event) => {
      const errorEvent = event as ErrorEvent
      const detail = formatWorkerError(errorEvent)
      console.error("Prometheus worker error event:", event)
      console.error("Prometheus worker detail:", detail)
      rejectPendingWorkerRequests(detail)
      setActiveJob("idle")
      setLogs((current) => [...current, { level: "error", message: detail }])
      toast.error("Worker error")
      workerRef.current?.terminate()
      workerRef.current = null
    })

    worker.addEventListener("messageerror", (event) => {
      console.error("Prometheus worker message error:", event)
      rejectPendingWorkerRequests("Worker message decode failed.")
      setActiveJob("idle")
      setLogs((current) => [...current, { level: "error", message: "Worker message decode failed." }])
      toast.error("Worker message error")
      workerRef.current?.terminate()
      workerRef.current = null
    })
  }

  function createWorker() {
    const worker = new Worker(new URL("./worker/prometheus.worker.ts", import.meta.url), {
      type: "module",
    })
    workerRef.current = worker
    setupWorker(worker)
    return worker
  }

  function stopCurrentJob() {
    if (activeJob === "idle") {
      return
    }

    rejectPendingWorkerRequests("Execution stopped by user.")
    workerRef.current?.terminate()
    workerRef.current = null
    createWorker()
    setActiveJob("idle")
    setLogs((current) => [...current, { level: "warn", message: "Execution stopped by user." }])
    toast("Execution stopped")
  }

  useEffect(() => {
    const workerUrl = new URL("./worker/prometheus.worker.ts", import.meta.url).toString()
    workerUrlRef.current = workerUrl
    createWorker()

    return () => {
      workerRef.current?.terminate()
      workerRef.current = null
    }
  }, [])

  const canExport = output.trim().length > 0
  const isBusy = activeJob !== "idle"
  const isObfuscating = activeJob === "obfuscate"
  const isRunningInput = activeJob === "run-input"
  const isRunningOutput = activeJob === "run-output"
  const docsHref = `${import.meta.env.BASE_URL}docs/index.html`

  async function sendWorkerRequest(request: WorkerRequest): Promise<PrometheusResult> {
    try {
      let worker = workerRef.current
      if (window.location.protocol === "file:") {
        return {
          ok: false,
          error:
            "Worker cannot run from file://. Serve the app over http:// or https:// (for example with `pnpm --filter web dev` or `pnpm --filter web preview`).",
          logs: [],
        }
      }

      if (!worker) {
        worker = createWorker()
      }

      return new Promise<PrometheusResult>((resolve, reject) => {
        let settled = false
        const settle = (callback: () => void) => {
          if (settled) {
            return
          }
          settled = true
          window.clearTimeout(timeout)
          worker?.removeEventListener("message", listener)
          pendingWorkerRejectsRef.current.delete(rejectRequest)
          callback()
        }
        const rejectRequest = (error: Error) => settle(() => reject(error))
        const timeout = window.setTimeout(() => {
          rejectRequest(new Error("Worker timed out before returning a result."))
        }, WORKER_TIMEOUT_MS)

        const listener = (event: MessageEvent<WorkerResponse>) => {
          const response = event.data
          if (response.id !== request.id) {
            return
          }
          if (response.type === "log") {
            setLogs((current) => [...current, response.log])
            return
          }
          if (response.type !== "result") {
            return
          }
          settle(() => resolve(response.result))
        }
        pendingWorkerRejectsRef.current.add(rejectRequest)
        worker?.addEventListener("message", listener)
        worker?.postMessage(request)
      }).catch((error): PrometheusResult => {
        return {
          ok: false,
          error: error instanceof Error ? error.message : String(error),
          logs: [],
        }
      })
    } catch (error) {
      return {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
        logs: [],
      }
    }
  }

  async function obfuscate(override?: {
    sharedOutputHash?: string | null
    options?: {
      source: string
      preset: PresetName
      luaVersion: LuaVersion
      prettyPrint: boolean
      seed: number
    }
  }) {
    if (isBusy && !override) {
      return
    }

    setActiveJob("obfuscate")
    try {
      setLogs([])
      const id = ++requestIdRef.current
      const options = override?.options ?? { source, preset, luaVersion, prettyPrint, seed }
      const request: WorkerRequest = {
        id,
        action: "obfuscate",
        options: {
          source: options.source,
          filename: "browser-input.lua",
          preset: options.preset,
          luaVersion: options.luaVersion,
          prettyPrint: options.prettyPrint,
          seed: options.seed,
        },
      }

      const result = await sendWorkerRequest(request)
      setLogs(result.logs)

      if (result.ok) {
        const outputHash = await sha256Hex(result.output)
        setLastObfuscation({
          source: options.source,
          preset: options.preset,
          luaVersion: options.luaVersion,
          prettyPrint: options.prettyPrint,
          seed: options.seed,
          outputHash,
        })
        setOutput(result.output)
        setSeed(createSeed())
        if (typeof override?.sharedOutputHash === "string") {
          if (outputHash !== override.sharedOutputHash) {
            setOutput("")
            setLogs((current) => [
              ...current,
              {
                level: "error",
                message:
                  "This shared link was generated using an older version of Prometheus and no longer produces the intended obfuscated result.",
              },
            ])
            toast.error("Shared link hash mismatch")
            return
          }
          toast.success("Shared link loaded")
          return
        }
        toast.success("Obfuscation complete")
        return
      }

      setLastObfuscation({
        source: options.source,
        preset: options.preset,
        luaVersion: options.luaVersion,
        prettyPrint: options.prettyPrint,
        seed: options.seed,
        outputHash: null,
      })
      setOutput("")
      setLogs([...result.logs, { level: "error", message: result.error }])
      toast.error("Obfuscation failed")
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      setOutput("")
      setLogs((current) => [...current, { level: "error", message }])
      toast.error("Obfuscation failed")
    } finally {
      setActiveJob("idle")
    }
  }

  async function shareLink() {
    if (!lastObfuscation) {
      return
    }

    const payload: SharePayload = {
      version: 1,
      source: lastObfuscation.source,
      preset: lastObfuscation.preset,
      luaVersion: lastObfuscation.luaVersion,
      prettyPrint: lastObfuscation.prettyPrint,
      seed: lastObfuscation.seed,
      outputHash: lastObfuscation.outputHash,
    }
    const encoded = encodeBase64Url(JSON.stringify(payload))
    const shareUrl = new URL(window.location.href)
    shareUrl.searchParams.set("share", encoded)
    window.history.replaceState({}, "", shareUrl)
    await navigator.clipboard.writeText(shareUrl.toString())
    toast.success("Share link copied")
  }

  async function runScript(kind: "input" | "output") {
    if (isBusy) {
      return
    }

    const script = kind === "input" ? source : output
    if (!script.trim()) {
      setLogs([{ level: "warn", message: `No ${kind} script to run.` }])
      return
    }

    setActiveJob(kind === "input" ? "run-input" : "run-output")
    setLogs([])
    const id = ++requestIdRef.current
    const request: WorkerRequest = {
      id,
      action: "runScript",
      source: script,
      filename: kind === "input" ? "browser-input.lua" : "browser-output.lua",
    }

    const result = await sendWorkerRequest(request)
    setActiveJob("idle")

    if (result.ok) {
      setLogs((current) => {
        if (current.length > 0) {
          return current
        }
        if (result.logs.length > 0) {
          return result.logs
        }
        return [{ level: "info", message: "Script finished without output." }]
      })
      toast.success("Script execution complete")
      return
    }

    setLogs([...result.logs, { level: "error", message: result.error }])
    toast.error("Script execution failed")
  }

  async function copyOutput() {
    if (!canExport) {
      return
    }
    await navigator.clipboard.writeText(output)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1200)
  }

  useEffect(() => {
    if (autoShareLoadedRef.current || isBusy) {
      return
    }

    const encoded = new URL(window.location.href).searchParams.get("share")
    if (!encoded) {
      return
    }

    const timeout = window.setTimeout(() => {
      autoShareLoadedRef.current = true
      let payload: SharePayload | null = null
      try {
        payload = JSON.parse(decodeBase64Url(encoded)) as SharePayload
      } catch {
        setLogs([{ level: "error", message: "Invalid shared link payload." }])
        toast.error("Invalid shared link")
        return
      }

      if (
        payload.version !== 1 ||
        !PRESETS.includes(payload.preset) ||
        !LUA_VERSIONS.includes(payload.luaVersion) ||
        typeof payload.source !== "string" ||
        typeof payload.prettyPrint !== "boolean" ||
        typeof payload.seed !== "number" ||
        (typeof payload.outputHash !== "string" && payload.outputHash !== null)
      ) {
        setLogs([{ level: "error", message: "Invalid shared link payload." }])
        toast.error("Invalid shared link")
        return
      }

      setSource(payload.source)
      setPreset(payload.preset)
      setLuaVersion(payload.luaVersion)
      setPrettyPrint(payload.prettyPrint)
      setSeed(Math.max(1, Math.floor(payload.seed)))
      void obfuscate({
        sharedOutputHash: payload.outputHash,
        options: {
          source: payload.source,
          preset: payload.preset,
          luaVersion: payload.luaVersion,
          prettyPrint: payload.prettyPrint,
          seed: payload.seed,
        },
      })
    }, 0)

    return () => window.clearTimeout(timeout)
  }, [isBusy])

  return (
    <TooltipProvider>
      <main className="flex h-screen min-h-0 flex-col overflow-hidden">
        <header className="border-b bg-card">
          <div className="mx-auto flex w-full max-w-[1600px] flex-col gap-3 px-4 py-3 lg:flex-row lg:items-center lg:justify-between">
            <div className="flex items-center gap-3">
              <div className="flex size-9 items-center justify-center rounded-md bg-primary text-primary-foreground">
                <FileCode2 className="size-5" />
              </div>
              <div>
                <h1 className="text-lg font-semibold leading-tight">Prometheus Playground</h1>
                <p className="text-xs text-muted-foreground">
                  In-browser Lua obfuscation powered by Prometheus by levno-710.
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2 text-sm">
              <span className="text-xs text-muted-foreground">If you like this tool, leave a star on</span>
              <a
                href="https://github.com/prometheus-lua/Prometheus"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 rounded-md border bg-background px-3 py-1.5 text-xs font-medium text-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
              >
                GitHub
                <Github className="size-3.5" />
              </a>
              <a
                href={docsHref}
                className="inline-flex items-center gap-2 rounded-md border bg-background px-3 py-1.5 text-xs font-medium text-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
              >
                Docs
                <BookText className="size-3.5" />
              </a>
              <Button onClick={isObfuscating ? stopCurrentJob : () => void obfuscate()} disabled={isBusy && !isObfuscating} className="min-w-32">
                {isObfuscating ? <Loader2 className="animate-spin" /> : <Play />}
                {isObfuscating ? "Stop" : "Obfuscate"}
              </Button>
            </div>
          </div>
        </header>

        <section className="border-b bg-background">
          <div className="mx-auto grid w-full max-w-[1600px] gap-3 px-4 py-3 md:grid-cols-2 xl:grid-cols-[180px_160px_150px_210px_auto] xl:items-end">
            <div className="space-y-1.5">
              <Label>Preset</Label>
              <Select value={preset} onValueChange={(value) => setPreset(value as PresetName)}>
                <SelectTrigger disabled={isBusy}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PRESETS.map((item) => (
                    <SelectItem key={item} value={item}>
                      {item}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Lua Version</Label>
              <Select value={luaVersion} onValueChange={(value) => setLuaVersion(value as LuaVersion)}>
                <SelectTrigger disabled={isBusy}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {LUA_VERSIONS.map((item) => (
                    <SelectItem key={item} value={item}>
                      {item}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex h-10 items-center gap-2 self-end rounded-md border bg-card px-3">
              <Switch checked={prettyPrint} onCheckedChange={setPrettyPrint} id="pretty-print" disabled={isBusy} />
              <Label htmlFor="pretty-print" className="text-sm">
                Pretty print
              </Label>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="seed">Seed</Label>
              <div className="flex gap-2">
                <Input
                  id="seed"
                  type="number"
                  min={1}
                  value={seed}
                  disabled={isBusy}
                  onChange={(event) => setSeed(Math.max(1, Number(event.target.value) || 1))}
                />
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="outline" size="icon" onClick={() => setSeed(createSeed())} disabled={isBusy} aria-label="Generate seed">
                      <RotateCcw />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>Generate seed</TooltipContent>
                </Tooltip>
              </div>
            </div>
            <div className="flex gap-2 self-end">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="outline" size="icon" onClick={copyOutput} disabled={!canExport} aria-label="Copy output">
                    {copied ? <Check /> : <Copy />}
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Copy output</TooltipContent>
              </Tooltip>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="outline" size="icon" onClick={() => downloadLua(output)} disabled={!canExport} aria-label="Download output">
                    <Download />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Download output</TooltipContent>
              </Tooltip>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="outline" size="icon" onClick={shareLink} disabled={!lastObfuscation} aria-label="Share link">
                    <Share2 />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Share link</TooltipContent>
              </Tooltip>
            </div>
          </div>
        </section>

        <section className="mx-auto grid min-h-0 w-full max-w-[1600px] flex-1 gap-3 overflow-hidden px-4 py-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_340px]">
          <CodeEditor
            label="Lua input"
            value={source}
            onChange={setSource}
            className="max-h-[560px] xl:max-h-none"
            actionButton={{
              label: isRunningInput ? "Stop" : "Run",
              icon: isRunningInput ? <Square /> : <Play />,
              onClick: isRunningInput ? stopCurrentJob : () => runScript("input"),
              disabled: isBusy && !isRunningInput,
            }}
          />
          <CodeEditor
            label="Obfuscated output"
            value={output}
            readOnly
            className="max-h-[560px] xl:max-h-none"
            actionButton={{
              label: isRunningOutput ? "Stop" : "Run",
              icon: isRunningOutput ? <Square /> : <Play />,
              onClick: isRunningOutput ? stopCurrentJob : () => runScript("output"),
              disabled: isBusy && !isRunningOutput,
            }}
          />
          <aside className="flex min-h-0 min-w-0 max-h-[280px] flex-col overflow-hidden rounded-md border bg-card xl:max-h-none">
            <div className="px-3 py-2 text-xs font-medium text-muted-foreground">Logs</div>
            <Separator />
            <ScrollArea className="min-h-0 flex-1">
              <div className="space-y-2 p-3 text-xs">
                {logs.length === 0 ? (
                  <p className="text-muted-foreground">No logs yet.</p>
                ) : (
                  logs.map((log, index) => (
                    <div key={`${log.level}-${index}`} className="rounded-md border bg-background px-2 py-1.5">
                      <span className="font-medium uppercase text-muted-foreground">{log.level}</span>{" "}
                      <span className={log.level === "error" ? "text-destructive" : ""}>{log.message}</span>
                    </div>
                  ))
                )}
              </div>
            </ScrollArea>
          </aside>
        </section>
      </main>
      <Toaster />
    </TooltipProvider>
  )
}

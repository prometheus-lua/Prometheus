
import { useEffect, useRef, useState } from "react"
import {
  Check, Copy, Download, FileCode2, Loader2, Upload, Zap, Shield,
} from "lucide-react"
import { toast, Toaster } from "sonner"
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
print(message)`

const styles = `
*{box-sizing:border-box;border-radius:0!important}
html,body,#root{margin:0;min-height:100%;background:#080808;color:#ededed}
body{font-family:Inter,system-ui,-apple-system,sans-serif;font-size:13px}
button,input,select,textarea{font:inherit}
button{cursor:pointer}
button:disabled{opacity:.4;cursor:not-allowed}
button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:2px solid #eee;outline-offset:2px}
.app{min-height:100vh;background:#080808}
.topbar{min-height:68px;border-bottom:1px solid #292929;display:flex;align-items:center;justify-content:space-between;padding:14px 22px;gap:12px}
.brand{display:flex;align-items:center;gap:12px}
.brand-icon{width:36px;height:36px;border:1px solid #444;display:grid;place-items:center;background:#121212}
.brand-name{font-size:15px;font-weight:750;letter-spacing:.02em}
.brand-sub{font-size:11px;color:#858585;margin-top:4px}
.top-actions,.panel-actions{display:flex;align-items:center;gap:7px}
.btn,.small-btn{min-height:36px;border:1px solid #393939;background:#111;color:#e5e5e5;padding:0 12px;display:inline-flex;align-items:center;justify-content:center;gap:7px;transition:background .15s,border-color .15s}
.btn:hover:not(:disabled),.small-btn:hover:not(:disabled){background:#222;border-color:#777}
.btn-primary{background:#eee;color:#080808;border-color:#eee;font-weight:700}
.btn-primary:hover:not(:disabled){background:#ccc;color:#000}
.toolbar{display:flex;align-items:center;gap:18px;flex-wrap:wrap;padding:15px 22px;border-bottom:1px solid #252525;background:#0b0b0b}
.field{display:flex;align-items:center;gap:9px}
.field label{font-size:11px;color:#999}
.select,.seed-input{height:36px;border:1px solid #353535;background:#111;color:#e5e5e5;padding:0 10px;outline:none}
.select:focus,.seed-input:focus{border-color:#aaa}
.seed-input{width:130px}
.workspace{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:14px;padding:18px 22px}
.panel{min-width:0;border:1px solid #292929;background:#0c0c0c}
.panel-head{min-height:49px;padding:10px 12px;display:flex;align-items:center;justify-content:space-between;gap:8px;border-bottom:1px solid #292929}
.panel-title{display:flex;align-items:center;gap:9px;font-weight:650;font-size:12px}
.dot{width:7px;height:7px;background:#777;flex-shrink:0}
.editor{display:block;width:100%;height:390px;resize:vertical;border:0;outline:0;padding:16px;background:#090909;color:#e5e5e5;font:12px/1.8 "SFMono-Regular",Consolas,monospace;white-space:pre;overflow:auto}
.editor:focus{box-shadow:inset 0 0 0 1px #444}
.editor::placeholder{color:#555}
.panel-foot{min-height:38px;padding:9px 12px;border-top:1px solid #292929;display:flex;align-items:center;justify-content:space-between;color:#777;font-size:10px}
.upload-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;padding:0 22px 18px}
.hint{font-size:11px;color:#888}
.toggle-card{display:flex;align-items:center;gap:14px;padding:12px 14px;border:1px solid #303030;background:#0c0c0c;min-height:62px}
.toggle-card.enabled{border-color:#aaa;background:#131313}
.toggle-copy{display:flex;flex-direction:column;gap:5px}
.toggle-title{display:flex;align-items:center;gap:7px;font-weight:650;font-size:12px}
.toggle-desc{font-size:10px;color:#888}
.switch{position:relative;width:38px;height:21px;flex-shrink:0;display:inline-block}
.switch input{position:absolute;opacity:0;width:1px;height:1px}
.switch-track{position:absolute;inset:0;background:#292929;border:1px solid #555;transition:background .15s}
.switch-track:after{content:"";position:absolute;width:13px;height:13px;left:3px;top:3px;background:#aaa;transition:transform .15s}
.switch input:checked+.switch-track{background:#ddd;border-color:#ddd}
.switch input:checked+.switch-track:after{transform:translateX(17px);background:#111}
.switch input:focus-visible+.switch-track{outline:2px solid white;outline-offset:3px}
.logs{margin:0 22px 22px;border:1px solid #292929;background:#090909}
.logs-head{padding:12px 14px;border-bottom:1px solid #292929;color:#bbb;font-size:11px;font-weight:700}
.logs-body{padding:12px 14px;min-height:45px;max-height:170px;overflow:auto;font:11px/1.8 monospace;color:#888;white-space:pre-wrap;overflow-wrap:anywhere}
.log-error{color:#ff8585}.log-warn{color:#e4c47b}.log-info{color:#aaa}
.status{display:flex;align-items:center;gap:7px}
.status-dot{width:6px;height:6px;background:#555}
.status-dot.ok{background:#76d5a1}
.hidden-file{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}
.footer{padding:0 22px 20px;color:#666;font-size:10px;display:flex;justify-content:space-between}
@media(max-width:760px){
 .topbar{padding:12px;align-items:center}
 .brand-sub{max-width:180px;line-height:1.4}
 .hide-mobile{display:none}
 .toolbar{padding:12px;gap:12px}
 .field{flex:1;min-width:125px;justify-content:space-between}
 .select{max-width:145px;width:100%;min-width:0}
 .seed-input{width:100px}
 .workspace{grid-template-columns:minmax(0,1fr);padding:12px;gap:12px}
 .editor{height:290px}
 .upload-row{padding:0 12px 14px;align-items:stretch}
 .toggle-card{justify-content:space-between;width:100%}
 .logs{margin:0 12px 18px}
 .footer{padding:0 12px 16px}
 .panel-head{align-items:flex-start}
 .panel-actions{flex-wrap:wrap;justify-content:flex-end}
}
@media(prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important}}
`

function makeSeed() {
  const values = new Uint32Array(1)
  if (globalThis.crypto?.getRandomValues) {
    globalThis.crypto.getRandomValues(values)
    return (values[0] % 2147483646) + 1
  }
  return Math.floor(Math.random() * 2147483646) + 1
}

function saveLua(text: string) {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = "paca.obfuscated.lua"
  document.body.appendChild(a)
  a.click()
  a.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 1000)
}


export default function App() {
  const [source, setSource] = useState(initialSource)
  const [output, setOutput] = useState("")
  const [preset, setPreset] = useState<PresetName>("Medium")
  const [luaVersion, setLuaVersion] = useState<LuaVersion>("Lua51")
  const [seed, setSeed] = useState(makeSeed)
  const [prettyPrint, setPrettyPrint] = useState(false)
  const [busy, setBusy] = useState(false)
  const [copied, setCopied] = useState(false)
  const [logs, setLogs] = useState<PrometheusLog[]>([])
  const workerRef = useRef<Worker | null>(null)
  const requestId = useRef(0)

  useEffect(() => {
    const worker = new Worker(
      new URL("./worker/prometheus.worker.ts", import.meta.url),
      { type: "module" },
    )
    workerRef.current = worker

    worker.onerror = (event) => {
      setLogs((old) => [
        ...old,
        { level: "error", message: event.message || "작업 처리 중 오류가 발생했습니다." },
      ])
      setBusy(false)
      toast.error("작업 처리 중 오류가 발생했습니다.")
    }

    return () => {
      worker.terminate()
      workerRef.current = null
    }
  }, [])

  async function obfuscate() {
    if (busy) return

    if (!source.trim()) {
      toast.error("Lua 코드를 입력해 주세요.")
      return
    }

    setBusy(true)
    setOutput("")
    setLogs([])
    const id = ++requestId.current

    try {
      let worker = workerRef.current

      if (!worker) {
        worker = new Worker(
          new URL("./worker/prometheus.worker.ts", import.meta.url),
          { type: "module" },
        )
        workerRef.current = worker
      }

      const request: WorkerRequest = {
        id,
        action: "obfuscate",
        options: {
          source,
          filename: "input.lua",
          preset,
          luaVersion,
          prettyPrint,
          seed,
        },
      }

      const result = await new Promise<PrometheusResult>((resolve, reject) => {
        const timeout = window.setTimeout(() => {
          cleanup()
          worker?.terminate()
          if (workerRef.current === worker) workerRef.current = null
          reject(new Error("처리 시간이 초과되어 작업을 중단했습니다. 코드를 줄이거나 강도를 낮춰 다시 시도해 주세요."))
        }, 90000)

        const cleanup = () => {
          window.clearTimeout(timeout)
          worker!.removeEventListener("message", listener)
          worker!.removeEventListener("error", onError)
        }

        const onError = (event: ErrorEvent) => {
          cleanup()
          reject(new Error(event.message || "백그라운드 엔진에서 오류가 발생했습니다."))
        }

        const listener = (event: MessageEvent<WorkerResponse>) => {
          const message = event.data
          if (message.id !== id) return

          if (message.type === "log") {
            setLogs((old) => [...old, message.log])
            return
          }

          if (message.type === "result") {
            cleanup()
            resolve(message.result)
          }
        }

        worker!.addEventListener("message", listener)
        worker!.addEventListener("error", onError)
        worker!.postMessage(request)
      })

      setLogs((old) => [...old, ...result.logs])

      if (result.ok) {
        setOutput(result.output)
        setSeed(makeSeed())
        toast.success("난독화가 완료되었습니다.")
      } else {
        setLogs((old) => [
          ...old,
          { level: "error", message: result.error },
        ])
        toast.error("난독화에 실패했습니다. 실행 로그를 확인해 주세요.")
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      setLogs((old) => [...old, { level: "error", message }])
      toast.error("실행 중 오류가 발생했습니다. 실행 로그를 확인해 주세요.")
    } finally {
      setBusy(false)
    }
  }

  async function copyOutput() {
    if (!output) {
      toast.error("복사할 결과가 없습니다.")
      return
    }

    try {
      await navigator.clipboard.writeText(output)
      setCopied(true)
      toast.success("결과를 클립보드에 복사했습니다.")
      window.setTimeout(() => setCopied(false), 1500)
    } catch {
      toast.error("클립보드에 접근할 수 없습니다.")
    }
  }

  async function uploadFile(file?: File) {
    if (!file) return

    try {
      setSource(await file.text())
      setOutput("")
      setLogs([])
      toast.success("파일을 불러왔습니다.")
    } catch {
      toast.error("파일을 읽지 못했습니다.")
    }
  }

  return (
    <div className="app">
      <style>{styles}</style>

      <header className="topbar">
        <div className="brand">
          <div className="brand-icon"><FileCode2 size={18} /></div>
          <div>
            <div className="brand-name">Paca 난독화기</div>
            <div className="brand-sub">Lua Source Protection</div>
          </div>
        </div>

        <div className="top-actions">
          <a
            className="btn hide-mobile"
            href="https://github.com/qwerqwerg1u/PACA"
            target="_blank"
            rel="noreferrer"
            style={{ textDecoration: "none" }}
          >
            PACA GitHub
          </a>
          <button className="btn btn-primary" onClick={obfuscate} disabled={busy}>
            {busy ? <Loader2 size={14} className="spin" /> : <Zap size={14} />}
            {busy ? "처리 중..." : "난독화"}
          </button>
        </div>
      </header>

      <section className="toolbar">
        <div className="field">
          <label htmlFor="preset">강도</label>
          <select id="preset" className="select" value={preset} disabled={busy}
            onChange={(e) => setPreset(e.target.value as PresetName)}>
            {PRESETS.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </div>

        <div className="field">
          <label htmlFor="lua-version">Lua 버전</label>
          <select id="lua-version" className="select" value={luaVersion} disabled={busy}
            onChange={(e) => setLuaVersion(e.target.value as LuaVersion)}>
            {LUA_VERSIONS.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </div>

        <div className="field">
          <label htmlFor="seed">Seed</label>
          <input id="seed" className="seed-input" type="number" min="1"
            value={seed} disabled={busy}
            onChange={(e) => setSeed(Math.max(1, Number(e.target.value) || 1))} />
        </div>

        <label className="field" style={{ cursor: "pointer" }}>
          <input type="checkbox" checked={prettyPrint} disabled={busy}
            onChange={(e) => setPrettyPrint(e.target.checked)} />
          <span style={{ color: "#aaa", fontSize: 11 }}>Pretty print</span>
        </label>
      </section>

      <main className="workspace">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title"><span className="dot" />입력 코드</div>
            <div className="panel-actions">
              <label className="small-btn" style={{ cursor: "pointer", position: "relative", overflow: "hidden" }}>
                <Upload size={13} />파일 열기
                <input className="hidden-file" type="file" accept=".lua,.luau,.txt,text/plain"
                  onChange={(e) => {
                    void uploadFile(e.currentTarget.files?.[0])
                    e.currentTarget.value = ""
                  }} />
              </label>
              <button className="small-btn" onClick={() => setSource("")}
                disabled={!source || busy}>지우기</button>
            </div>
          </div>

          <textarea className="editor" value={source}
            onChange={(e) => setSource(e.target.value)}
            placeholder="Lua 코드를 입력해 주세요." spellCheck={false}
            autoCapitalize="off" autoCorrect="off" aria-label="Lua 입력 코드" />

          <div className="panel-foot">
            <span>Lua 소스</span>
            <span>{source.length.toLocaleString()}자</span>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="dot" style={{ background: output ? "#76d5a1" : "#555" }} />
              난독화 결과
            </div>
            <div className="panel-actions">
              <button className="small-btn" onClick={copyOutput} disabled={!output}>
                {copied ? <Check size={13} /> : <Copy size={13} />}
                {copied ? "복사 완료" : "복사"}
              </button>
              <button className="small-btn" onClick={() => saveLua(output)} disabled={!output}>
                <Download size={13} />다운로드
              </button>
            </div>
          </div>

          <textarea className="editor" value={output} readOnly
            placeholder="난독화 결과가 여기에 표시됩니다." spellCheck={false}
            aria-label="난독화 결과" />

          <div className="panel-foot">
            <span className="status">
              <span className={`status-dot ${output ? "ok" : ""}`} />
              {output ? "완료" : "대기 중"}
            </span>
            <span>{output.length.toLocaleString()}자</span>
          </div>
        </section>
      </main>

      <section className="upload-row">
        <div className="toggle-card enabled">
          <div className="toggle-copy">
            <div className="toggle-title"><Shield size={14} />로컬 VM 엔진</div>
            <div className="toggle-desc">외부 Anti-Tamper 파일이나 런타임 loadstring에 의존하지 않습니다.</div>
          </div>
        </div>

        <button className="btn btn-primary" onClick={obfuscate} disabled={busy}>
          {busy ? <Loader2 size={14} className="spin" /> : <Zap size={14} />}
          {busy ? "처리 중..." : "난독화 실행"}
        </button>
        <span className="hint">Strong은 문자열·상수 변환 후 사용자 정의 VM으로 한 번 컴파일합니다.</span>
      </section>

      <section className="logs">
        <div className="logs-head">실행 로그</div>
        <div className="logs-body">
          {logs.length === 0 ? "표시할 로그가 없습니다." : logs.map((log, index) => (
            <div key={`${log.level}-${index}`}
              className={log.level === "error" ? "log-error" : log.level === "warn" ? "log-warn" : "log-info"}>
              [{log.level.toUpperCase()}] {log.message}
            </div>
          ))}
        </div>
      </section>

      <footer className="footer">
        <span>Paca 난독화기</span>
        <span>Lua Source Protection</span>
      </footer>

      <Toaster
        theme="dark"
        position="top-center"
        closeButton
        richColors
        toastOptions={{
          style: {
            background: "#111",
            color: "#f2f2f2",
            border: "1px solid #444",
            borderRadius: 0,
            boxShadow: "0 8px 30px #0009",
          },
        }}
      />
    </div>
  )
}

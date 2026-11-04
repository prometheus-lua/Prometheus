import { StreamLanguage, defaultHighlightStyle, syntaxHighlighting } from "@codemirror/language"
import { lua } from "@codemirror/legacy-modes/mode/lua"
import { EditorState } from "@codemirror/state"
import { EditorView, highlightActiveLine, highlightActiveLineGutter, lineNumbers } from "@codemirror/view"
import type { ReactNode } from "react"
import { useEffect, useRef } from "react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"

interface CodeEditorProps {
  value: string
  onChange?: (value: string) => void
  readOnly?: boolean
  label: string
  className?: string
  actionButton?: {
    label: string
    icon?: ReactNode
    onClick: () => void
    disabled?: boolean
  }
}

export function CodeEditor({ value, onChange, readOnly = false, label, className, actionButton }: CodeEditorProps) {
  const parentRef = useRef<HTMLDivElement | null>(null)
  const viewRef = useRef<EditorView | null>(null)
  const valueRef = useRef(value)
  valueRef.current = value

  useEffect(() => {
    if (!parentRef.current) {
      return
    }

    const view = new EditorView({
      parent: parentRef.current,
      state: EditorState.create({
        doc: valueRef.current,
        extensions: [
          lineNumbers(),
          highlightActiveLineGutter(),
          highlightActiveLine(),
          StreamLanguage.define(lua),
          syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
          EditorView.lineWrapping,
          EditorView.editable.of(!readOnly),
          EditorState.readOnly.of(readOnly),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) {
              onChange?.(update.state.doc.toString())
            }
          }),
          EditorView.theme({
            "&": {
              color: "var(--foreground)",
            },
            ".cm-content": {
              padding: "12px 0",
            },
            ".cm-gutters": {
              backgroundColor: "transparent",
              borderRight: "1px solid var(--border)",
              color: "var(--muted-foreground)",
            },
            ".cm-activeLine": {
              backgroundColor: "color-mix(in oklch, var(--accent) 35%, transparent)",
            },
            ".cm-activeLineGutter": {
              backgroundColor: "color-mix(in oklch, var(--accent) 45%, transparent)",
            },
          }),
        ],
      }),
    })

    viewRef.current = view
    return () => {
      view.destroy()
      viewRef.current = null
    }
  }, [onChange, readOnly])

  useEffect(() => {
    const view = viewRef.current
    if (!view || view.state.doc.toString() === value) {
      return
    }

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: value },
    })
  }, [value])

  return (
    <div className={cn("flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-md border bg-card", className)} aria-label={label}>
      <div className="flex items-center justify-between gap-2 border-b px-3 py-2 text-xs font-medium text-muted-foreground">
        <span>{label}</span>
        {actionButton ? (
          <Button size="sm" onClick={actionButton.onClick} disabled={actionButton.disabled} className="h-7 px-2 text-xs">
            {actionButton.icon}
            {actionButton.label}
          </Button>
        ) : null}
      </div>
      <div ref={parentRef} className="min-h-0 flex-1 overflow-hidden" />
    </div>
  )
}

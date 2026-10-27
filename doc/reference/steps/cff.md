# Step: Cff

Constructor key: `Cff`; `ControlFlowFlattening` is also accepted.

`Cff` flattens control flow into Lua statements executed by a block dispatcher. It remains available alongside the register VM step, `Vmify`.

When `Cff` receives `Vmify` output, it recognizes the private VM runtime annotation and flattens the interpreter function only. The prototype tables remain outside the flattened function so large data initializers do not expand the control flow graph beyond Lua or LuaJIT limits. Read-only external lexical helpers are forwarded as function arguments; if the interpreter writes to an external lexical variable, `Cff` uses its ordinary compilation path instead.

## Settings

None.

## Example

```lua
{ Name = "Cff", Settings = {} }
```

Use `Cff` when you want the control flow flattening behavior. Existing configs that used the old `Vmify` key for this behavior should use `Cff` now. The `Vmify` key compiles code to the register VM.

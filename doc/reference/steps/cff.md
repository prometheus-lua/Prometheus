# Step: Cff

Constructor key: `Cff`; `ControlFlowFlattening` is also accepted.

`Cff` flattens control flow into Lua statements executed by a block dispatcher. It remains available alongside the register VM step, `Vmify`.

When `Cff` receives `Vmify` output, it recognizes the private VM runtime annotation. By default, it flattens the interpreter function and leaves the prototype tables outside it, so large data initializers do not expand the control flow graph beyond Lua or LuaJIT limits. Read-only external lexical helpers are forwarded as function arguments; if the interpreter writes to an external lexical variable, `Cff` uses its ordinary compilation path instead.

Set `ExcludeVm` to `true` to leave the generated interpreter and native prototype table literal out of Cff flattening. Cff then flattens the surrounding code, including helpers such as decoders and tamper checks, and the outer string initializer emitted by `EncryptStrings` when `HoistVmStrings` is enabled. The interpreter keeps its native Lua lexical captures, preserving shared variable behavior between the interpreter and surrounding closures.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `ExcludeVm` | boolean | `false` | When true, leave the generated VM interpreter and prototype table literal out of Cff flattening. |

## Example

```lua
{ Name = "Cff", Settings = {} }
```

To flatten code surrounding a generated VM while leaving the VM itself native:

```lua
{ Name = "Cff", Settings = { ExcludeVm = true } }
```

Use `Cff` when you want the control flow flattening behavior. Existing configs that used the old `Vmify` key for this behavior should use `Cff` now. The `Vmify` key compiles code to the register VM.

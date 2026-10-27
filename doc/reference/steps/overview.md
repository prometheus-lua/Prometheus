# Step Pipeline Overview

Prometheus applies each configured step to the AST in the order listed in `Steps`.

After step application, Prometheus performs variable renaming and then unparses code.

## Registered step constructor keys

Use one of these constructor keys in `Steps[i].Name`:

- `WrapInFunction`
- `SplitStrings`
- `Cff` (also accepted as `ControlFlowFlattening`)
- `ConstantArray`
- `ProxifyLocals`
- `AntiTamper`
- `EncryptStrings`
- `NumbersToExpressions`
- `AddVararg`
- `WatermarkCheck`

## General step config shape

```lua
{
  Name = "Cff",
  Settings = {}
}
```

## Notes

- Some constructor keys differ from internal human-readable names.
- `Cff` is the existing control-flow flattening step and has no settings. `ControlFlowFlattening` is also accepted as a constructor key alias.
- `Vmify` is reserved for a future real VM step and is not registered in this milestone.
- You can apply the same step more than once.
- If a step returns a new AST, that AST is used for later steps.

# Step Pipeline Overview

Prometheus applies configured steps in the order listed in `Steps`. A step can return a new AST for the following steps to process. After the steps run, Prometheus performs variable renaming and unparses the code.

## Registered step constructor keys

Use these constructor keys in `Steps[i].Name`:

- `WrapInFunction`
- `SplitStrings`
- `Cff` (also accepted as `ControlFlowFlattening`)
- `Vmify`
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
  Name = "Vmify",
  Settings = {}
}
```

## Notes

- `Cff` flattens control flow into Lua statements dispatched through blocks. It has no settings; `ControlFlowFlattening` is accepted as an alias.
- `Vmify` compiles the AST into register instructions and data tables, then emits Lua code with an interpreter for that data. It has no settings.
- `Vmify` and `Cff` are separate steps and may both appear in a pipeline. Later steps receive the AST returned by the previous step.
- You can apply the same step more than once.

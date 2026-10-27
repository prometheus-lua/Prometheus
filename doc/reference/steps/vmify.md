# Step: Vmify

Constructor key: `Vmify`.

`Vmify` compiles the AST into per-function register instructions, constants, and prototype data, then emits Lua code with an interpreter that executes that data. This is the table-backed register VM step. It compiles the AST directly; it does not first apply `Cff`.

## Settings

None.

## Example

```lua
{ Name = "Vmify", Settings = {} }
```

`Vmify` is a different step from `Cff`, which performs control flow flattening. If an older config used `Vmify` to select the former control flow flattening behavior, change that step to `Cff`. The `Vmify` name now selects the register VM.

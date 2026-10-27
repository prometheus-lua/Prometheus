# Step: Vmify

Constructor key: `Vmify`.

`Vmify` compiles the AST into per-function register instructions, constants, and prototype data, then emits Lua code with an interpreter that executes that data. This is the table-backed register VM step. It compiles the AST directly; it does not first apply `Cff`.

Each emitted chunk uses a generated instruction layout. Opcode IDs are
permuted, and the operand fields use a permuted selection of slots 2 through 5;
slot 1 always stores the opcode. The same layout applies to the root function
and its child prototypes. For the same input, configuration, and Lua runtime,
a fixed pipeline seed reproduces the layout.

## Settings

None.

## Example

```lua
{ Name = "Vmify", Settings = {} }
```

`Vmify` is a different step from `Cff`, which performs control flow flattening. If an older config used `Vmify` to select the former control flow flattening behavior, change that step to `Cff`. The `Vmify` name now selects the register VM.

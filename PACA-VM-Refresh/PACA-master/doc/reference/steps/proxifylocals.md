# Step: ProxifyLocals

Constructor key: `ProxifyLocals`

Wraps local variable accesses through proxy/metatable operations.

## Settings

| Key | Type | Default | Values |
| --- | --- | --- | --- |
| `LiteralType` | enum | `"string"` | `dictionary`, `number`, `string`, `any` |

## Example

```lua
{ Name = "ProxifyLocals", Settings = { LiteralType = "any" } }
```

## Notes

- Global variables are not transformed.
- Function arguments and loop variables are excluded from proxification.

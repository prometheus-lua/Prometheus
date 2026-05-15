# Step: NumbersToExpressions

Constructor key: `NumbersToExpressions`

Rewrites number literals as arithmetic expressions and optionally mutates numeric representation format.

## Settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `Threshold` | number | `1` | probability `0..1` for transforming number literals |
| `InternalThreshold` | number | `0.2` | recursion/representation cutoff (`0..0.8`) |
| `NumberRepresentationMutation` | boolean | `false` | enables representation mutation |
| `AllowedNumberRepresentations` | table | `{ "hex", "scientific", "normal" }` | options include `binary` |

## Example

```lua
{
  Name = "NumbersToExpressions",
  Settings = {
    Threshold = 1,
    InternalThreshold = 0.2,
    NumberRepresentationMutation = true,
    AllowedNumberRepresentations = { "hex", "scientific", "normal" },
  }
}
```

## Notes

- If `binary` is enabled in allowed representations, Prometheus warns that binary literals need Lua 5.2+ syntax support.
- Legacy key `NumberRepresentationMutaton` is still accepted for backward compatibility.

# Step: AntiTamper

Constructor key: `AntiTamper`

Injects anti-tamper and anti-hook checks. If tamper checks fail, runtime execution is intentionally broken.

## Settings

| Key | Type | Default |
| --- | --- | --- |
| `UseDebug` | boolean | `true` |

## Behavior notes

- If pipeline `PrettyPrint` is enabled, this step logs a warning and is skipped.
- With `UseDebug = true`, generated code uses debug-library-based checks.

## Example

```lua
{ Name = "AntiTamper", Settings = { UseDebug = false } }
```

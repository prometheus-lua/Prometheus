# Step: SplitStrings

Constructor key: `SplitStrings`

Splits string literals into chunks and reconstructs them at runtime.

## Settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `Threshold` | number | `1` | probability per candidate string (`0..1`) |
| `MinLength` | number | `5` | minimum chunk length (`>=1`) |
| `MaxLength` | number | `5` | maximum chunk length (`>=1`) |
| `ConcatenationType` | enum | `"custom"` | `strcat`, `table`, `custom` |
| `CustomFunctionType` | enum | `"global"` | `global`, `local`, `inline` (used when `custom`) |
| `CustomLocalFunctionsCount` | number | `2` | used when `CustomFunctionType = "local"` |

## Example

```lua
{
  Name = "SplitStrings",
  Settings = {
    Threshold = 0.8,
    MinLength = 3,
    MaxLength = 8,
    ConcatenationType = "custom",
    CustomFunctionType = "local",
    CustomLocalFunctionsCount = 2,
  }
}
```

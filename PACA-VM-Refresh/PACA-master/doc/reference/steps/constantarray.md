# Step: ConstantArray

Constructor key: `ConstantArray`

Extracts constants into an array and replaces direct constants with indexed access/wrapper calls.

## Settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `Threshold` | number | `1` | probability `0..1` |
| `StringsOnly` | boolean | `false` | when `true`, only string constants are moved |
| `Shuffle` | boolean | `true` | shuffles array order |
| `Rotate` | boolean | `true` | rotates array and injects runtime un-rotate logic |
| `LocalWrapperThreshold` | number | `1` | probability `0..1` |
| `LocalWrapperCount` | number | `0` | wrapper functions per function scope |
| `LocalWrapperArgCount` | number | `10` | wrapper function argument count |
| `MaxWrapperOffset` | number | `65535` | max random index offset |
| `Encoding` | enum | `"mixed"` | `none`, `base64`, `base85`, `mixed` |

## Example

```lua
{
  Name = "ConstantArray",
  Settings = {
    Threshold = 1,
    StringsOnly = true,
    Shuffle = true,
    Rotate = true,
    LocalWrapperThreshold = 0,
    LocalWrapperCount = 0,
    Encoding = "mixed",
  }
}
```

Legacy keys `Treshold` and `LocalWrapperTreshold` are still accepted for backward compatibility.

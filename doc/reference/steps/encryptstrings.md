# Step: EncryptStrings

Constructor key: `EncryptStrings`

Encrypts string literals and injects runtime decryption logic.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `HoistVmStrings` | boolean | `false` | With `Vmify` output, hoist string literals from the generated interpreter into an outer initializer. |

When enabled after `Vmify`, interpreter strings are encrypted by the normal
`EncryptStrings` flow and can be processed by later steps such as
`ConstantArray` and `Cff`. The initializer decodes them once at startup and
binds them to native lexical locals used by the interpreter, avoiding decoder
or wrapper calls on interpreter hot paths. Strings in the VM's `vmData`
prototype tables remain encrypted by the normal `EncryptStrings` behavior.
Without `Vmify` output, this setting has no effect.

## Example

```lua
{ Name = "EncryptStrings", Settings = {} }
```

To hoist interpreter strings in a pipeline after `Vmify`:

```lua
{ Name = "EncryptStrings", Settings = { HoistVmStrings = true } }
```

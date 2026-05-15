# How the Pipeline Works

Execution flow in `Pipeline:apply`:

1. Seed random generator (`Seed` or generated seed)
2. Parse source to AST
3. Apply configured steps in order
4. Rename variables
5. Unparse AST to Lua code

## Seeding details

- If `Seed > 0`: uses that fixed seed.
- Else Prometheus attempts `openssl rand -hex 12` for entropy.
- If OpenSSL is unavailable, it falls back to `os.time()` and logs a warning.

## Variable renaming

After all steps finish, Prometheus renames identifiers using:

- selected `NameGenerator`
- configured `VarNamePrefix`
- language keyword table for selected `LuaVersion`

## Logging

Pipeline emits informational logs for each phase and step timing, including output size relative to source.

# PACA maintenance update

## Reliability and VM pipeline

- Kept the existing custom bytecode VM; no runtime `loadstring` wrapper was added.
- Removed the redundant second `Vmify` pass from the Strong preset.
- Moved source transforms before the single VM compilation pass.
- Added string splitting to Strong while keeping it opt-in through that preset.
- Changed pipeline timing to prefer sub-second `os.clock()` on all platforms.
- Fixed output-size reporting for empty input.
- Removed the playground's remote Anti-Tamper fetch-and-prepend behavior. The page now uses only the checked-in local engine.
- Kept the legacy AntiTamper implementation out of built-in presets because its environment fingerprint checks are prone to false positives.
- Added worker termination on timeout so a stalled job does not poison later runs.
- Improved per-build seed generation with Web Crypto where available.

## Important limitations

- The VM compiler is the repository's existing Prometheus-derived compiler, not a newly invented VM.
- No obfuscator can guarantee that code delivered to an untrusted client is unrecoverable.
- Test generated output in the exact Lua/Luau runtime and API environment you intend to support.
- Anti-tamper checks are not a replacement for server-side validation, access control, or keeping secrets off clients.

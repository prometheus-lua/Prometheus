CI runs the full Lua suite for every PR targeting `master`. The shared
`actions/validate` action records the checked-out Git tree in a small artifact
named with the tree hash and run attempt. This identifies what was tested; only
a successful `Test.yml` workflow run makes it a passing result.

On a push to `master`, validation locates the merged PR's latest CI run. It
reuses that run only if its recorded tree matches the new `master` tree exactly.
This works across merge, squash, and rebase methods when the resulting files
are identical. Direct pushes, changed merge results, and missing or expired
artifacts fall back to the full suite.

On a `v*` tag, release validation looks for the latest `master` CI run for the
exact tagged commit, including annotated tags. It requires the same tree proof
and a successful conclusion. A queued or running CI run is awaited for up to
70 minutes before falling back to tests. Unavailable API results, cancelled
runs, and missing evidence also fall back to tests. A known failed validation
for the same source blocks progression; fix or rerun the failed CI run first.
Older successful runs never override a newer matching failure.

Successful fallback tests let the workflow continue. Each validation attempt
records its own source, so a master fallback can be reused by a subsequent tag.
Artifacts are retained for 90 days; older releases can still proceed by testing
again. Existing CI runs without validation artifacts also require fresh tests.
Recording an artifact is best effort: if uploading it fails, validation still
proceeds, and later stages fall back to tests when they cannot find the record.

Every reused result emits a notice, an explicit skipped-suite step, and a
workflow summary explaining the skip, with the matching tree, source run URL,
and attempt number. Fallback and blocked decisions also explain their reason
in the summary.

Release packages are built on Linux and macOS, then extracted into a temporary
directory and smoke-tested (version, help, obfuscation, and execution using the
bundled runtime). Publishing requires both packages and their smoke tests to
succeed. The normal PR → merge → tag → release path runs the full suite once.

Run the validation policy tests locally with:

```sh
node --test scripts/ci/reuse-validation.test.cjs
```

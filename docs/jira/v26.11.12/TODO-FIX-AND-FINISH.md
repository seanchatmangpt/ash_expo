# TODO-FIX-AND-FINISH (ash_expo)

Standing: UNVERIFIED

Source: `ash_surface/docs/jira/v26.11.11/PROJECT-REVIEWS.md` R5, re-read where marked confirmed.

## Fix

- HIGH `lib/ash_expo/codegen.ex:274-300` online_only refused in execute mode only when
  `options.getNetworkOnline` is supplied (confirmed); README example (`README.md:114-118`)
  omits it (confirmed). Check: offline execute of online_only action refused by default.
- HIGH `codegen.ex:248-271` absolute URLs pass `resolveInput`; `authenticatedFetch` attaches
  bearer with no origin check (confirmed). Check: token not sent to a foreign origin.
- MED `test/ash_expo_test.exs:140-166` substring-only TS checks, absolute-us bounds in
  `codegen_bench_bound_test.exs:20-72`: UNVERIFIED (not read).
- LOW stale jira docs: UNVERIFIED.

## Finish

- Add a runtime test that executes generated TS. Check: test runs the client against a fake
  fetch and asserts admission outcomes.
- Create `templates/` dir or drop `[templates] dir` in `ggen.toml:10-11` (confirmed dir
  missing from `ls`).
- Replace absolute-time bench bounds with ratio fences.

## Commit hygiene

- `mix.lock` untracked (confirmed `??`); CI cache keyed on it UNVERIFIED.
- `docs/` untracked (confirmed `??`).
Check: `git status --short` shows none.

## Decide

- Default for `getNetworkOnline` absent: fail closed or require it.
- Allowed origins policy for token attachment.

## Reuse

- Offline admission (`codegen.ex:274-300`) once fail-open fixed.
- `resource/verifiers/validate_projection.ex`, `track_channel_config.ex` (UNVERIFIED paths).

## See Also

`ash_surface/docs/jira/v26.11.11/PROJECT-REVIEWS.md`

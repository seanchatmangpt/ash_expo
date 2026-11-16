# ash_expo migration plan v26.11.16

Standing: UNVERIFIED

## Identity
- Path: /Users/sac/ash_expo
- Remote: https://github.com/seanchatmangpt/ash_expo.git
- Branch: test/end-to-end-codegen@6f876f5 (tracks origin, ahead 0 / behind 0)
- Last commit: 2026-10-07; commits: 26; size: <1 MB
- Languages/build: Elixir (mix.exs), ggen.toml, ontology.ttl
- Nested repos: none

## Observed state
- Dirty 0. Untracked: `docs/` (jira v26.11.12, v26.9.19) and `mix.lock`
- main is 17 behind origin/main (local main stale, harmless)
- Stash 0. No _build/deps present.

## What it is
Projects an Ash Framework app's admitted public actions into an Expo-friendly TypeScript
runtime; Ash stays authoritative. Status 0.1.0-dev, first vertical slice.

## Classification
ACTIVE (census agrees).

## Migration risk
LOW. Only untracked docs/ and mix.lock would be lost.

## Recommended action
COMMIT-PUSH
1. DECISION: should mix.lock be tracked? (library repos often do).
2. `cd /Users/sac/ash_expo && git add docs mix.lock && git commit -m "docs: jira catalogue"`
3. `git push origin test/end-to-end-codegen`
4. CLONE-FRESH on new machine; no build dirs to clean.

## First commands on the new machine
`mix deps.get && mix test`

## See Also
- ../v26.11.12/
- /Users/sac/docs/jira/v26.11.16/README.md

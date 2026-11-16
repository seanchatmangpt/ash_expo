# ash_expo: land or delete remote branch `feat/ash-expo-v0-1`

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: remote branch `feat/ash-expo-v0-1` — not merged into `main`, no open PR
- Evidence: `git branch -r --no-merged origin/main` lists it; absent from `gh pr list` heads

## Work to complete
- Decide: open a PR (`gh pr create -R seanchatmangpt/ash_expo --head feat/ash-expo-v0-1`) or delete (`git push origin --delete feat/ash-expo-v0-1`).
- If superseded, delete; otherwise land through review.

## Acceptance
- After `git fetch --prune`, `git branch -r --no-merged origin/main` no longer lists `feat/ash-expo-v0-1`.

## History
- 2026-09-19 | OPEN | survey found PR-less unmerged branch | feat/ash-expo-v0-1 | decision pending

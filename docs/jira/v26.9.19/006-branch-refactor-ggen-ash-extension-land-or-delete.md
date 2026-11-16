# ash_expo: land or delete remote branch `refactor/ggen-ash-extension`

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: remote branch `refactor/ggen-ash-extension` — not merged into `main`, no open PR
- Evidence: `git branch -r --no-merged origin/main` lists it; absent from `gh pr list` heads

## Work to complete
- Decide: open a PR (`gh pr create -R seanchatmangpt/ash_expo --head refactor/ggen-ash-extension`) or delete (`git push origin --delete refactor/ggen-ash-extension`).
- If superseded, delete; otherwise land through review.

## Acceptance
- After `git fetch --prune`, `git branch -r --no-merged origin/main` no longer lists `refactor/ggen-ash-extension`.

## History
- 2026-09-19 | OPEN | survey found PR-less unmerged branch | refactor/ggen-ash-extension | decision pending

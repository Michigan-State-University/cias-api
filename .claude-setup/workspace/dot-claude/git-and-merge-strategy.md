# Git Branching, PR & Merge Strategy (workspace)

How code flows to production across the CIAS repos. **Confirmed for `cias-web`**
(June 2026) — `cias-api` is believed to mirror this; verify its branch names before
relying on them there.

## Promotion flow

Code is promoted through three long-lived environment branches, never committed to directly:

```
feature branch  →  dev  →  test  →  master (production)
```

- **feature branch** — one per ticket (e.g. `CIAS30-4117-improve-modal-to-import-intervention`,
  `cias-4177-fix-date-picker-timezone`). Branched from `dev`, merged back into `dev` via PR.
- **dev** — integration branch. Default branch on GitHub (`origin/HEAD -> origin/dev`).
- **test** — staging/QA. Deployed to the `cias-test-dokku1` / `cias-test-dokku2` remotes.
- **master** — production. Deployed to `cias-prod-dokku1` / `cias-prod-dokku2` remotes.

## Dated integration branches (the promotion mechanism)

Promotion between environments is **not** a direct `dev → test` / `test → master` merge.
It goes through a throwaway dated branch, opened as a PR into the target:

- `dev → test` via a branch named `dev_to_test_<DDMMYYYY>` (e.g. `dev_to_test_20052026`)
- `test → master` via a branch named `test_to_master_<DDMMYYYY>` (e.g. `test_to_master_30042026`)

So `master`'s first-parent history is a chain of `Merge pull request #NNN from .../test_to_master_<date>`
commits — each one a release. To see releases:

```bash
git log --oneline --first-parent origin/master
```

## Remotes (deploy targets — Dokku, not just GitHub)

```
origin            github.com/Michigan-State-University/<repo>    # source of truth
cias-prod-dokku1  dokku@<prod-box-1>:<repo>                       # production
cias-prod-dokku2  dokku@<prod-box-2>:<repo>                       # production
cias-test-dokku1  dokku@<test-box-1>:<repo>                       # staging/test
cias-test-dokku2  dokku@<test-box-2>:<repo>                       # staging/test
```

The box addresses are deliberately not in this file (the repos are public) — get them from the
team vault, or `git remote -v` in an existing checkout. Pushing to a `*-dokku*` remote deploys.
`origin` is GitHub. Two boxes per env (1 & 2) for redundancy / blue-green. The new ECS stack
(`test-ecs.cias.app`) deploys through its own pipeline, not through a git remote. **Never deploy
without the team's go-ahead, and never to production on your own.**

## Reading a promotion PR's diff (important gotcha)

GitHub's "Files changed" tab uses a **three-dot diff from the merge base**, so a
`test_to_master_<date>` PR will list *every* change made on the source side since the
branches last diverged — including changes master already has (e.g. a hotfix that was
also landed on dev). Those files appear in the diff but the merge applies **no net
change** to master for them and **won't conflict** (3-way merge sees identical content).

Verify any "why is this here again?" surprise with a read-only merge simulation:

```bash
MB=$(git merge-base origin/master origin/test)
git diff --stat $MB...origin/test            # what the PR will SHOW
git merge-tree --write-tree origin/master origin/test >/dev/null 2>&1 \
  && echo CLEAN || echo CONFLICTS             # whether it actually conflicts
```

## Hotfixes (urgent fix straight to production)

When a fix can't wait for the full `dev → test → master` promotion, it goes **directly
to master** — but must also be back-ported so the env branches don't diverge. The
repo-specific procedure (with a worked example) lives in
[cias-web/rules/hotfix-flow.md](cias-web/rules/hotfix-flow.md). The rule in one line:

> **Hotfix off `master`, merge to `master`, then `git cherry-pick` the *same commit*
> back to `dev`** — don't re-author the fix on dev by hand.

## Golden rules

- Never commit directly to `dev` / `test` / `master`. Always via PR.
- Branch features from `dev`; branch hotfixes from `master`.
- Promote with dated integration branches, not ad-hoc direct merges.
- After any hotfix, immediately back-port the commit to `dev` (cherry-pick) so the
  three branches stay reconciled.

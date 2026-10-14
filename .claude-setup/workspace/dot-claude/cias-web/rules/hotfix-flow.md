# Hotfix Flow (cias-web)

How to ship an urgent fix straight to production (`master`) when it can't wait for the
normal `feature → dev → test → master` promotion. See the workspace-level
[git-and-merge-strategy.md](../../git-and-merge-strategy.md) for the overall branch model.

## The rule (one line)

> **Branch the hotfix from `master`, merge it to `master`, then `git cherry-pick` the
> *same commit* back to `dev`** — don't re-author the fix on `dev` by hand.

Cherry-picking the identical commit (not a hand-made twin) guarantees the content is
byte-identical across branches, so the next regular `test → master` promotion merges
trivially with no conflict and no duplicate logic.

## Procedure

```bash
git fetch origin

# 1. Branch the hotfix from master (NOT from dev — that would drag unreleased dev work onto prod)
git checkout -b cias-XXXX-hotfix origin/master
#    ...make the fix, commit...

# 2. PR the hotfix branch into master, merge, deploy (push to cias-prod-dokku1/2)

# 3. Back-port the SAME commit to dev, then let it ride the normal flow to test
git checkout -b cias-XXXX-backport-to-dev origin/dev
git cherry-pick <hotfix-code-commit-sha>     # the CODE commit, NOT the merge commit
#    ...PR into dev; it flows dev → dev_to_test_<date> → test naturally...
```

**Cherry-pick the code commit, never the merge commit.** Picking a merge commit needs
`-m` and takes the wrong base — you'll get the whole branch, not the fix.

## Worked example — `cias-4177-fix-date-picker-timezone` (June 2026)

What actually happened, as a reference for "is my hotfix reconciled?":

- Hotfix branched from old master `0b253066` (PR #395 release), one commit `f71e437b`,
  merged to master as `8dc68c76` (PR #400). ✅ master got *only* the fix, no dev pollution.
- The same fix also reached `dev` as a **parallel** commit `c9c804f6` (different SHA,
  identical content) and flowed to `test` via `dev_to_test_20052026` (PR #401).
- All three branches ended up reconciled — but by luck of identical content, not by the
  cherry-pick rule above. Had the two versions drifted, the next promotion would conflict.

### How to verify a hotfix is reconciled across branches

```bash
# patch-equivalence: leading '-' means "already present upstream by patch"
git cherry origin/dev  <hotfix-sha>
git cherry origin/test <hotfix-sha>

# definitive: identical patch-id == byte-for-byte same change
git show <hotfix-sha>  | git patch-id --stable
git show origin/dev    | git patch-id --stable   # compare the hashes
```

In the cias-4177 case both branches returned `-` and the patch-ids matched
(`fbd8c273…`), confirming the fix was genuinely everywhere.

## Gotcha: the fix reappears in the next promotion PR's diff

When the next `test_to_master_<date>` PR is opened, the hotfixed files **will show up in
the "Files changed" tab** (GitHub diffs from the merge base, and the fix was committed on
the test side after that base). This is cosmetic — the merge applies **no net change** to
master for those files and **won't conflict**. Confirm with a read-only simulation:

```bash
git merge-tree --write-tree origin/master origin/test >/dev/null 2>&1 \
  && echo CLEAN || echo CONFLICTS
```

---
description: Bump vulnerable gems from a bundler-audit report — research each upgrade for breaking changes, then apply conservative bumps on an isolated branch and verify with bundler-audit + tests.
argument-hint: <paste the bundler-audit report, or leave empty to run bundler-audit>
---

You are running the **gem-bump flow** for the CIAS workspace (Ruby / Bundler, `cias-api`). The user pasted an audit report:

<report>
$ARGUMENTS
</report>

Goal: clear the flagged advisories with the **smallest, safest** version bumps, after confirming each upgrade won't break the app. Be conservative and evidence-driven — research before bumping, never guess.

Run everything from inside `cias-api/` with the repo's Ruby (`cat .ruby-version`). The Claude Bash shell may not load your shell profile, so check `ruby -v` once: if it doesn't match, call `bundle` / `ruby` / `gem` through your version manager's wrapper or shim instead (rvm: `~/.rvm/wrappers/ruby-<version>/bundle`; rbenv: `~/.rbenv/shims/bundle`; asdf/mise: their shims). Below, `bundle`, `ruby` and `gem` mean that resolved binary.

---

## Step 0 — Get a report

If `<report>` above is empty (or clearly not an audit report), generate one yourself instead of asking:

```bash
gem install bundler-audit --no-document
cd cias-api && ruby -S bundler-audit check --update
```

If it's already clean ("No vulnerabilities found"), report that and stop.

## Step 1 — Parse into a worklist

Turn the report into a table. One row per **gem** (collapse multiple advisories for the same gem):

| Gem | Current (locked) | Advisories | Max criticality | Min safe version (`>= X`) |
|---|---|---|---|---|

- "Current (locked)" must come from `cias-api/Gemfile.lock`, not the report — verify it: `grep -E "^    (<gem>) \(" Gemfile.lock`.
- "Min safe version" = the highest `Solution: update to '>= X'` across that gem's advisories.
- Note whether each gem is **direct** (in `Gemfile`) or **transitive** (only in the lock): `grep -nE "<gem>" Gemfile`. This matters for how you pin it later.

## Step 2 — Pick a conservative target for each gem

The target is the **lowest released version that clears every advisory for that gem**, preferring to stay within the **current major, ideally the current minor**. Do **not** jump to "latest" just because it's available.

- Patch bump (`x.y.Z`) → lowest risk; almost never needs code changes.
- Minor bump (`x.Y.z`) → usually safe (semver), but read the changelog for deprecations/behavior changes.
- Major bump (`X.y.z`) → treat as **not a routine bump**. If an advisory is only fixed in a new major, do **not** auto-apply: produce a short migration note (what breaks, what code must change) and surface it for a human decision.

## Step 3 — Research each bump (this is the important part — don't skip)

For every gem, before changing anything, gather evidence:

1. **The advisory** — WebFetch the GHSA/CVE URL(s) from the report. Understand the vuln and whether the fix **changed any public API** (most security patches don't).
2. **The changelog / releases between current → target** — for **every** gem and **every** version in the range, read the full text: the gem's `CHANGELOG.md` at the target tag, or its GitHub releases (`gh api repos/<org>/<gem>/releases/tags/<tag> --jq .body`; on macOS run read-only `gh` outside the sandbox if it fails with `x509: OSStatus -26276`). Look specifically for: "breaking", "removed", "deprecated", "requires Ruby >= …", changed defaults. A keyword grep, a WebFetch summary or a truncated excerpt is not a changelog review, and a semver level + green tests is not a substitute — if you skipped or skimmed one, say so in the report. Use `WebSearch` if you can't find the changelog URL, and `mcp__context7__*` for a migration guide on bigger jumps.
3. **Blast radius in this codebase** — grep for direct use of the gem's API to judge whether any behavior change actually touches us, e.g. `grep -rn "Oj\.\|Oj::" app/ lib/`, `Nokogiri`, `Faraday`. A transitive gem we never call directly is lower risk than one we use everywhere.

Classify each as: **SAFE** (patch/minor, no relevant breaking change) / **REVIEW** (minor/major with changes that may touch our usage) / **BLOCKED** (needs code changes or a major migration — do not auto-bump).

Present the findings table and your intended targets **before** mutating anything.

## Step 4 — Isolated branch

Branch off the integration base (`dev`), never bundle this into a feature branch. Follow `.claude/git-and-merge-strategy.md`:

```bash
cd cias-api && git checkout dev && git pull
git checkout -b chore/bundler-audit-gem-bumps   # or chore/bump-<gem> for a single gem
```

If the working tree is dirty with **unrelated** changes, leave them — you will hand the lockfile change to the user to commit (Step 7). Do not stash, commit, or touch anything you didn't change here.

## Step 5 — Apply the bumps (conservatively)

Bump only the **SAFE** (and explicitly-approved **REVIEW**) gems, in one shot:

```bash
bundle update <gem1> <gem2> … --conservative
```

`--conservative` avoids cascading updates to shared dependencies. Then **verify the resulting versions**:

```bash
git diff Gemfile.lock | grep -E "^[+-]    (<gem1>|<gem2>) "
```

- Confirm each new version is `>=` its min-safe target.
- If `bundle update` **overshot** into a new minor/major you didn't intend (and Step 3 flagged risk there), constrain it: tighten the `Gemfile` requirement to the safe-but-minimal range (e.g. `gem 'nokogiri', '~> 1.19.4'`) or add `'< NEXT_MAJOR'`, re-run, and re-verify. Prefer the smallest jump that clears the advisory.
- Check the lock's `PLATFORMS` / native-gem platform entries are preserved (e.g. linux entry for CI/prod isn't dropped).

## Step 6 — Verify

```bash
# 1. lockfile is DEPLOY-CLEAN in frozen mode — this is the check that matters most.
#    Local `bundle update` runs non-frozen and silently self-heals; the production
#    image builds with BUNDLE_DEPLOYMENT=1 (frozen), which does NOT. This step
#    reproduces the deploy build's strictness so drift is caught here, not in ECR/CI.
cd cias-api && BUNDLE_FROZEN=true bundle install   # expect: "Bundle complete!" and exit 0

# 2. advisories cleared (and none introduced)
ruby -S bundler-audit check --update   # expect: No vulnerabilities found

# 3. app still boots with the new native gems
bundle exec rails runner "puts 'BOOT OK'"

# 4. run the specs that exercise the bumped gems (from Step 3's blast-radius grep),
#    e.g. serializers (oj/json), HL7/sanitization (nokogiri), external API (faraday).
bundle exec rspec <relevant_spec_paths>
```

If check 1 fails with **"Your lockfile is missing a checksums entry for … but can't be updated because frozen mode is set"**, the `CHECKSUMS` block is out of sync with the resolved (GEM-section) versions — usually from a merge that combined a newer GEM section with an older `CHECKSUMS` section, or a bump made under a pre-2.5 Bundler. `--conservative` does **not** cause this. Reconcile the checksums (nothing else) and re-verify:

```bash
bundle lock --add-checksums   # rewrites only the CHECKSUMS block
git --no-pager diff Gemfile.lock                          # sanity-check: ONLY sha256 lines changed, versions match GEM section
```

State plainly what you ran and the real results. If a spec fails, surface the output — do not paper over it. The full suite is CI's job on the PR; say so.

## Step 7 — Hand off for the user to commit — do NOT commit (or push, or open a PR)

**Do not run `git add`, `git commit`, `git push`, or open a PR.** The user commits manually — your job ends at a verified, ready-to-commit working tree. Completing the bumps is **not** permission to commit; only commit if the user explicitly asks you to in a later message.

Show the user exactly what changed and give them a ready-to-use commit message they can run themselves:

- `git --no-pager diff --stat Gemfile.lock` (+ `Gemfile` if you tightened a constraint in Step 5) so they see the scope.
- A suggested commit message (present it — do **not** run it):

```
chore: bump gems flagged by bundler-audit

- <gem> <old> -> <new> (<CVE/GHSA ids>)
- …

bundler-audit check: no vulnerabilities found.

Co-Authored-By: <the attribution line for the current model>
```

**`cias-api` is a public repository.** Commit messages and PR bodies list only what was **fixed** — keep BLOCKED or deferred advisories (still-exploitable gems) out of them.

If — and only if — the user later asks you to commit, stage **only** what you changed — never `git add -A` (the working tree may hold unrelated changes): `git add Gemfile.lock` (+ `Gemfile` only if you constrained a version). Then **stop and ask again** before pushing / opening a PR (pushing is outward-facing). When asked, open the PR against `dev`.

## Step 8 — Final report

Give the user:
- The bump table (gem, old → new, advisories cleared, SAFE/REVIEW/BLOCKED, changelog link) — plus, per gem, which changelog source you actually read.
- Anything **BLOCKED** (needs code changes / major migration) with a short plan, listed separately — these are not done.
- Verification results (bundler-audit clean? boot? which specs ran?).
- The `git diff --stat` scope and a ready-to-use commit message — the user commits it themselves.
- Explicit next step: the tree is ready to commit; commit + push + PR are all pending your go-ahead (you do not commit on your own).
- The `Pills consulted:` line — usually `none — dependency bump`, unless a pill informed the blast-radius check.

---

## Guardrails (do not violate)
- **Conservative by default:** smallest version that clears the advisory; stay within the current major/minor unless forced higher.
- **Never auto-apply a major bump** or any bump your research flagged as needing code changes — surface it as BLOCKED with a plan.
- **Research before bumping:** every gem gets advisory + full changelog + blast-radius checks. No blind `bundle update`.
- **Public repo:** never put unfixed or deferred advisories in commit messages or PR bodies.
- **Isolate:** dedicated `chore/` branch off `dev`; never sweep unrelated working-tree changes. If the user later asks you to commit, stage **only** the lockfile (+ Gemfile if you constrained).
- **Verify:** frozen `bundle install` clean (deploy-valid lockfile — catches checksum/lock drift) + bundler-audit clean + boot + relevant specs, with honest results.
- **Never commit, push, or open a PR on your own** — the user commits manually; only do any of these when explicitly asked in that message.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.

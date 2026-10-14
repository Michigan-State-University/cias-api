---
description: Bump vulnerable npm packages from an npm audit report (cias-web) — collapse the report to root advisories, research each upgrade for breaking changes, then apply conservative bumps on an isolated branch and verify with npm ci + npm audit + tsc + tests + prod build.
argument-hint: <paste npm audit output (text or --json), a list of package names to scope to, `cleanup` to only delete reports of merged runs, or leave empty to run npm audit>
---

You are running the **npm-bump flow** for the CIAS workspace (Node / npm, `cias-web`). The user pasted:

<report>
$ARGUMENTS
</report>

Goal: clear the flagged advisories with the **smallest, safest** version bumps, after confirming each upgrade won't break the app. Be conservative and evidence-driven — research before bumping, never guess.

**Toolchain — always Node 22.** `package.json` `engines`, `.nvmrc`, CI (`.github/workflows/main.yml`) and the ECS `Dockerfile` all use Node 22. Your shell's default `node` may be a different major (e.g. Homebrew's latest) — that is wrong for this repo, and a different npm major can rewrite `package-lock.json` wholesale. Shell state doesn't persist between Bash calls, so prefix **every** `node` / `npm` / `npx` command with:

```bash
export PATH="$(ls -d "$HOME"/.nvm/versions/node/v22.* | sort -V | tail -1)/bin:$PATH" npm_config_cache="$TMPDIR/npm-cache" &&   # nvm; with fnm/volta/mise, put their Node 22 bin dir first instead
```

- `npm_config_cache` is needed because the sandbox can't write to `~/.npm/_cacache`. Without it, `npm view` / `install` / `ci` fail with a misleading *"Your cache folder contains root-owned files… run sudo chown"* message. **Don't chown anything** — that's the sandbox, not the files. The `$TMPDIR` cache starts cold, so the first `npm ci` downloads everything.
- Confirm once: `node -v` → `v22.*`. Run everything from inside `cias-web/`.
- npm contacts `registry.npmjs.org` — declare it in `allowed_domains`.
- `.npmrc` sets `legacy-peer-deps=true`; leave it (the install depends on it).

---

## Reports — saved for every run, deleted once the PR is merged

Every run writes its reports to files in a run folder, not only to chat:

```
.claude/cias-web/npm-bump-reports/<YYYY-MM-DD>-<topic>/    # workspace .claude — absolute path below
  report.md                 # the run's record (header + sections, see below)
  audit-before.json         # Step 0
  audit-before-prod.json
  audit-after.json          # Step 7
  audit-after-prod.json
```

```bash
# from inside cias-web/ — the workspace root is its parent
RUN="$(cd .. && pwd)/.claude/cias-web/npm-bump-reports/<YYYY-MM-DD>-<topic>" && mkdir -p "$RUN" && echo "$RUN"
```

Shell state doesn't persist between Bash calls: reuse the absolute path it printed in every later command.

- `<topic>`: the planned branch name with `/` → `-` (`chore-npm-audit-compression-proxy-addr`), or `pr-<n>-<pkg>` when reviewing a Dependabot PR. Cleanup reads the header, not the folder name, so the name doesn't need to change if the branch does.
- **Never committable:** the folder sits in the workspace `.claude/`, which is outside both git repos (the workspace root is not a repo). That matters: `report.md` lists **unfixed** advisories and `cias-web` is public. Never copy report content into the repo, a commit message or a PR body (Step 8).
- **Sandbox:** if your sandbox only allows writes inside `cias-web/`, a sandboxed command can't write there. Run the `npm audit … > "$RUN/…"` commands with the sandbox disabled (they need the registry anyway). The absolute path also avoids `$TMPDIR` resolving differently in sandboxed and unsandboxed calls.
- `report.md` starts with a header that the cleanup reads:

  ```
  ---
  branch: chore/npm-audit-compression-proxy-addr   # Dependabot review: its dependabot/... head branch
  pr: null                                        # PR number once known (Dependabot review: always)
  worktree: null                                  # path, if the work was done in a git worktree
  status: researching                             # researching | ready-to-commit | pr-open | blocked
  created: YYYY-MM-DD
  ---
  ```

  Then come the sections, each written **when its step finishes**, so an interrupted run still leaves a record: **Worklist** (Steps 1–2, including deferred), **Research** (Step 4: per package, the sources actually read, behaviour changes, verdict), **Verification** (Step 7: the commands and their real results), **Hand-off** (Step 8: diff stat + commit message).

### Cleanup — at the start of every run, and on `cleanup`

Before Step 0, delete the run folders whose PR has been merged. If `<report>` is just `cleanup`, do only this and stop. Also do it whenever the user says one of these PRs was merged.

For each folder under `npm-bump-reports/`:

1. Read `pr` and `branch` from the `report.md` header.
2. Look up the PR (sandbox disabled, like every `gh` call): `gh pr view <pr> --repo Michigan-State-University/cias-web --json state,mergedAt`, or, with no number yet, `gh pr list --repo Michigan-State-University/cias-web --head <branch> --state all --json number,state,mergedAt`.
3. **MERGED** → `rm -rf` that one folder. **OPEN**, or no PR yet → keep it (fill in `pr` / `status` if you just found the number). **CLOSED without merging** → ask the user whether to keep or delete it.
4. Tell the user which folders were removed and for which PR. If a removed run recorded a `worktree`, point it out, but don't remove worktrees or branches yourself (`git worktree remove <path>` / `git branch -d <branch>` are the user's call).

Deferred advisories are re-derived from a fresh audit on every run, so deleting a merged run's worklist loses nothing.

## Step 0 — Get a report

If `<report>` is empty (or clearly not an audit report), generate one yourself instead of asking:

```bash
npm audit --json > "$RUN/audit-before.json"; npm audit --omit=dev --json > "$RUN/audit-before-prod.json"
```

(`npm audit` exits 1 when it finds anything — that's not a failure.) If the user pasted a report, still generate the JSON so Step 7 has something to diff against. If the user pasted a **list of package names**, still generate the JSON, then scope the worklist to those names. Keep the `-before` files — Step 7 diffs against them.

If it reports 0 vulnerabilities, report that and stop.

**`cias-web/mjml/` is a separate npm project**: an email-template gulp tool with its own `package.json` and `package-lock.json`. It isn't part of CI or the app build. Dependabot PRs titled "… in /mjml" target it. Run the whole flow **from inside `mjml/`** in that case. To verify there, `npm ci` (sandbox disabled), then `npm run build` before *and* after the bump and compare the 5 generated `html/*.html` files byte for byte against the pre-bump build, **not** against git (the committed HTML is stale). Then `npm run lint`. Afterwards run `git checkout -- mjml/html` and remove `mjml/lib` and `mjml/node_modules`.
npm 11 may add a root `"name"` line to an older lockfile. That's harmless normalization; leave it.

## Step 1 — Collapse into root advisories

`npm audit` counts **every package on the path** to a vulnerable one, so its headline number hugely overstates the work. It's also **unstable**: which dependents it counts depends on the package metadata in npm's cache. On 2026-09-24 the same lockfile reported 209 with the stale `~/.npm` cache and 83 with a fresh `$TMPDIR` cache. Both runs had the same **43 packages that actually carry an advisory**. Track the root count, not the headline. Only root advisories (entries whose `via` holds advisory objects, not just package names) need fixing; the rest clear when they do. Collapse:

```bash
python3 - "$RUN/audit-before.json" <<'EOF'
import json, sys
audit = json.load(open(sys.argv[1]))
pkg = json.load(open('package.json'))
lock = json.load(open('package-lock.json'))['packages']
order = ['critical', 'high', 'moderate', 'low', 'info']
for name, v in sorted(audit['vulnerabilities'].items(), key=lambda kv: order.index(kv[1]['severity'])):
    advs = [a for a in v['via'] if isinstance(a, dict)]
    if not advs:
        continue  # flagged only because a dependency is vulnerable — not a root advisory
    section = 'dependencies' if name in pkg.get('dependencies', {}) else 'devDependencies' if name in pkg.get('devDependencies', {}) else 'transitive'
    locked = sorted({lock[n]['version'] for n in v['nodes'] if n in lock})
    print(f"{name} | {', '.join(locked)} | {section} | {v['severity']} | {len(advs)} | {'; '.join(sorted({a['range'] for a in advs}))} | {' '.join(a['url'] for a in advs)}")
EOF
```

Turn it into a worklist, one row per **package**:

| Package | Locked version(s) | Direct / transitive | Advisories | Max severity | Min safe version (per major line) | Exposure |
|---|---|---|---|---|---|---|

- **"Locked" comes from `package-lock.json`, not the report.** npm can hold **several copies** of one package (e.g. `form-data 2.3.3` *and* `4.0.5`). Each copy is on its own major line and needs its **own** min-safe version — `>= 2.5.6` for the 2.x copy, `>= 4.0.6` for the 4.x copy. `npm ls <pkg> --all` shows every copy and who pulls it in.
- **Min safe version** = the lowest version, on each installed major line, that is outside **every** advisory range for that line. Confirm it exists: `npm view <pkg> versions --json`.
- **Ignore `fixAvailable`** in the JSON — it is computed against the whole tree and is often wrong (it said `false` for `axios` even though a fixed 1.x is in range). Work out targets yourself in Step 3.
- **Direct vs transitive:** for transitive packages, `npm explain <pkg>` names the direct dependency (dependencies) that pull it in — that is usually what you actually bump.
- Optional: `gh pr list --repo Michigan-State-University/cias-web --author app/dependabot --state open` — Dependabot runs weekly; if an open PR already bumps a package, point it out rather than duplicating it. Also check that PR's CI (`gh pr view <n> --json statusCheckRollup`). In the sandbox, `gh` fails with `x509: OSStatus -26276` (Go can't verify the sandbox proxy's certificate). These read-only `gh` calls need to run with the sandbox disabled.
- A Dependabot **version-update** PR (not a security one) can be in scope when the user asks for it, even though it isn't in the audit. It gets the same research and verification. If it's a major, the user naming that exact target counts as approval for REVIEW.

## Step 2 — Classify exposure, then agree on a batch

Tag each row with where the vulnerable code actually runs. This decides priority far more than npm's severity label:

| Exposure | Meaning | How to tell |
|---|---|---|
| **BROWSER** | Shipped in the JS bundle to participants/researchers | imported from `app/` directly, or via a package that is (`npm explain` → a runtime lib) |
| **SERVER** | Runs in the production Express server — `node server` serves the build on both Dokku (`Procfile`) and ECS (`Dockerfile` `CMD`) | reached from `server/` (`express`, `compression`, `ip`, `body-parser`, `qs`, `path-to-regexp`, …) |
| **BUILD** | Runs only during `npm run build` (CI / Docker builder stage), pruned from the runtime image | webpack, babel, loaders, `image-webpack-loader`/imagemin, postcss |
| **DEV** | Only on developer machines / CI | jest, eslint, stylelint, cypress, playwright, plop, lint-staged, coveralls |

`npm audit --omit=dev` (the `-before-prod` file) is a rough cut of BROWSER+SERVER, but this repo's `dependencies`/`devDependencies` split isn't perfectly clean — confirm with `npm explain` + grep, not the section alone.

A single PR should be **one coherent batch**, not all 40 packages. Default batch: every **BROWSER/SERVER critical+high**, plus any BUILD/DEV package whose fix is a pure in-range lockfile refresh (cheap, near-zero risk). If the worklist has more than ~10 rows, present it grouped by exposure and **ask the user which batch to do now** (AskUserQuestion) before researching everything in depth. Write the full worklist — including what is deferred — to the **Worklist** section of `$RUN/report.md`.

## Step 3 — Pick a conservative target and fix mechanism for each package

The target is the **lowest released version that clears every advisory for that copy**, staying within the current major (ideally the current minor). Do **not** jump to "latest" just because it's there.

- Patch → lowest risk. Minor → usually safe, read the changelog. **Major → not a routine bump:** if the fix is only in a new major, don't auto-apply; write a short migration note and surface it for a human decision.

Then choose **how** to get there, in this order of preference:

1. **Lockfile-only refresh** — the fixed version already satisfies every dependent's declared range: `npm update <pkg>` (works for transitive packages too, and does **not** touch `package.json`). Smallest diff; prefer it.
2. **Direct dependency, target outside its current range:** `npm install <pkg>@<spec>`. **Keep the existing range style**: exact pins stay exact (`lodash`, `compression` are pinned → `npm install lodash@<target> --save-exact`), caret ranges stay caret (`npm install <pkg>@^<target>`).
3. **Transitive, pinned out of range by its parent:** bump the **parent** instead (from `npm explain`) — if a patch/minor of the parent pulls in the fixed child, do that.
4. **Last resort — `overrides`** in `package.json` (the repo already uses some: `braces`, `cross-spawn`, `on-headers`, scoped `ajv`). An override forces a version the parent never declared, so it is at least **REVIEW**. Prefer a **scoped** override (`"parent": { "child": "^x.y.z" }`) over a global one, and stay on the major the parent expects unless research proves compatibility.

**Never run `npm audit fix --force`** (it takes majors, and sometimes downgrades). Plain `npm audit fix` is allowed only as a preview — `npm audit fix --dry-run --json` — because it will happily touch dozens of unrelated packages.

## Step 4 — Research each bump (this is the important part — don't skip)

For every package in the batch, before changing anything:

1. **The advisory** — WebFetch the GHSA URL(s) from Step 1. Understand the vuln, whether it is reachable given the **exposure** you tagged (a ReDoS in a DEV-only glob parser is not the same as one in the Express server), and whether the fix changed a public API.
2. **Changelog / releases, current → target** — for **every** package and **every** version in the range, not only the headline ones. Fetch the full text of the GitHub releases (`gh api repos/<o>/<r>/releases/tags/<tag> --jq .body`, sandbox disabled), or the `CHANGELOG.md` sections at the target tag. If the repo has neither, fall back to the commit list (`gh api repos/<o>/<r>/compare/<from>...<to>`). `npm view <pkg> repository.url` gives the repo. Look for "breaking", "removed", "deprecated", changed defaults, and behaviour changes in code paths we use.
   - **Read the full text.** A keyword grep, a WebFetch summary, or an excerpt cut at N characters is not a changelog review. Those are what missed js-yaml 4.2's parsing change and axios 1.20's XHR change on the first pass (2026-09-28).
   - When splitting a `CHANGELOG.md`, split on the **version heading level only**. Splitting on `###` too drops the `### Security` / `### Changed` bodies.
   - A semver level (patch/minor) and a green test suite are evidence, but **not** a substitute for this step. If you skip or skim a package, say so in the report.
3. **Frontend compatibility checks** — cheap, and each one catches real breakage in this repo:
   - **React 17 peers:** `npm view <pkg>@<target> peerDependencies`. Many libraries dropped React 17 in newer versions. Because `.npmrc` has `legacy-peer-deps=true`, **npm will not warn you** about a peer mismatch — you have to check. A React-18-only target is **BLOCKED**.
   - **Node engine:** `npm view <pkg>@<target> engines` must allow Node 22.
   - **ESM-only releases:** if the target is ESM-only (`"type": "module"` with no CJS `exports`), it breaks Jest — `jest.config.js` `transformIgnorePatterns` only transpiles `@anycable/*`, `nanoevents`, `byte-size`, `axios` — and it breaks any CommonJS `require()` in `server/` or `internals/`. That's **REVIEW** at best (needs a `transformIgnorePatterns` entry) or **BLOCKED**.
   - **patch-package:** `patches/` pins **exact versions** (`babel-plugin-react-intl+8.2.25`, `react-lottie+1.2.3`). If a bump changes one of those, the patch must be regenerated or `postinstall` fails — and that kills the **Dokku and Docker builds** while CI stays green (CI installs with `--ignore-scripts`). Treat it as **BLOCKED** unless the patch is redone.
   - **Types:** a bumped `@types/*` package, or a library that ships its own `.d.ts`, can break `tsc`.
4. **Blast radius in this codebase** — grep for direct use: `grep -rnE "from '<pkg>(/[^']*)?'|require\('<pkg>" app/ server/ internals/`. A transitive package we never import is lower risk than one used everywhere (e.g. `axios` in every saga, `lodash` all over `app/`).

Classify each as **SAFE** (patch/minor, no relevant breaking change, compatibility checks pass) / **REVIEW** (minor/major or override that may touch our usage) / **BLOCKED** (needs code changes, a major migration, React 18, or a patch-package redo — do not auto-bump).

Present the findings table and your intended targets + mechanisms **before** mutating anything, and write them to the **Research** section of `$RUN/report.md`.

## Step 5 — Isolated branch

Branch off the integration base (`dev`), never bundle this into a feature branch. Follow `.claude/git-and-merge-strategy.md`:

```bash
cd cias-web && git checkout dev && git pull
git checkout -b chore/npm-audit-package-bumps   # or chore/bump-<pkg> for a single package
```

If the working tree is dirty with **unrelated** changes, leave them — you will hand the change to the user to commit (Step 8). Do not stash, commit, or touch anything you didn't change here. `git checkout dev` may fail if the dirty tree conflicts — stop and tell the user rather than forcing it.

Record the baseline before changing anything: the Step 0 audit JSON (already saved), and `npx tsc --noEmit -p tsconfig.json` (clean on `dev` as of 2026-09-24, ~10 s).

## Step 6 — Apply the bumps (conservatively)

Bump only the **SAFE** (and explicitly-approved **REVIEW**) packages, using the mechanism chosen in Step 3. Group same-mechanism packages into one command where you can:

```bash
npm update <pkg1> <pkg2> …                      # lockfile-only refreshes
npm install <pkg>@<spec> [--save-exact]         # direct deps outside their range
# overrides: edit package.json by hand, then `npm install` to re-resolve
```

Then **verify the resulting versions**:

```bash
git --no-pager diff --stat package.json package-lock.json
npm ls <pkg1> <pkg2> … --all                    # EVERY copy of each package — not just the top-level one
```

- Confirm **every copy** of each package is `>=` the min-safe version for its major line. The top-level copy getting fixed while a nested copy stays vulnerable is the most common npm trap — re-check with `npm ls`.
- If npm **overshot** into a minor/major you didn't intend (and Step 4 flagged risk there), constrain it — tighten the range, or scope the override — re-run, and re-verify.
- Sanity-check the lockfile diff size. A lockfile-only refresh of 3 packages should change a handful of entries; thousands of changed lines mean the wrong npm version or a lockfile rewrite — stop, `git checkout package-lock.json`, and re-check the toolchain.
- `package.json` should change **only** where you intended (range bump or override). `engines`, `.npmrc` and `patches/` stay as they are.

## Step 7 — Verify

```bash
# 1. lockfile is DEPLOY-CLEAN — the check that matters most.
#    CI, the Dokku buildpack and the ECS Dockerfile all install with `npm ci`, which fails
#    if package.json and package-lock.json disagree (a local `npm install` silently
#    reconciles them). Run it WITH scripts: Dokku and Docker run the patch-package
#    postinstall, CI's `--ignore-scripts` does not — so this is the only place a broken
#    patch shows up before deploy. (`npm ci` wipes and reinstalls node_modules — a few minutes.)
CYPRESS_INSTALL_BINARY=0 npm ci                 # expect: exit 0, patch-package "✔" for both patches
#    Run this one with the SANDBOX DISABLED. The sandbox blocks deleting any file named
#    `.gitmodules`, and some packages ship one (node_modules/extsprintf/.gitmodules). A sandboxed
#    `npm ci` dies with EPERM halfway through and leaves node_modules PARTLY DELETED.
#    Unsandboxed, $TMPDIR may differ: pass npm_config_cache as an absolute path.
#    CYPRESS_INSTALL_BINARY=0 skips the ~200 MB Cypress binary download, which is irrelevant here.

# 2. targeted advisories cleared, nothing new introduced
npm audit --json > "$RUN/audit-after.json"; npm audit --omit=dev --json > "$RUN/audit-after-prod.json"
#    Re-run the Step 1 collapse on the -after file and diff against -before:
#    every package in this batch must be gone, and no NEW root advisory may appear.
#    The total will NOT be zero (deferred batches remain) — report before → after counts.

# 3. types still check — the prod build does NOT type-check (ts-loader transpileOnly in production)
npx tsc --noEmit -p tsconfig.json               # expect: exit 0, as at baseline

# 4. tests that exercise the bumped packages (from Step 4's blast-radius grep).
#    Don't use `npm test` — its `pretest` runs the full lint and wipes coverage/.
npx cross-env NODE_ENV=test jest <relevant test paths>
#    If jest, babel, jsdom or anything in the transform chain was bumped, run the full
#    suite instead (several minutes): npx cross-env NODE_ENV=test jest

# 5. lint — only if eslint / stylelint / @typescript-eslint / prettier / babel were in the batch
npm run lint

# 6. production bundle still builds (the "app boots" check for a SPA)
npm run build                                   # expect: webpack compiles with no errors
```

In the sandbox, `cias-web/.env` is read-denied, so the build prints a dotenv-webpack `Failed to load ./.env` warning and bakes in empty env values. That's fine for a compile check. If the build fails *because of* the sandbox, give the user `! npm run build` to run themselves rather than bypassing it.

For **BROWSER**-exposed bumps (e.g. `axios` → every API call and the auth-header interceptors; `dompurify` / `quill` → rich-text rendering), the compile check won't prove runtime behavior. Recommend a short smoke test of the affected flows (`npm start` locally, or `/qa-run` against test after deploy) and say which flows.

State plainly what you ran and the real results, and record them in the **Verification** section of `$RUN/report.md`. If a check fails, surface the output — do not paper over it. The full suite + lint on every push is CI's job on the PR; say so.

## Step 8 — Hand off for the user to commit — do NOT commit (or push, or open a PR)

**Do not run `git add`, `git commit`, `git push`, or open a PR.** The user commits manually — your job ends at a verified, ready-to-commit working tree. Completing the bumps is **not** permission to commit; only commit if the user explicitly asks you to in a later message.

Show exactly what changed and give a ready-to-use commit message:

- `git --no-pager diff --stat package.json package-lock.json` (+ `patches/` or `jest.config.js` if an approved REVIEW item needed them).
- A suggested commit message (present it — do **not** run it):

```
chore: bump npm packages flagged by npm audit

- <pkg> <old> -> <new> (<GHSA ids>)
- <pkg> (transitive via <parent>) <old> -> <new> (<GHSA ids>)
- …

npm audit: <N before> -> <N after> vulnerabilities; all advisories in this batch cleared.

Co-Authored-By: <the attribution line for the current model>
```

**`cias-web` is a public repository.** Commit messages and PR bodies list only what was **fixed**. Keep deferred and BLOCKED advisories (still-exploitable packages) out of them — that list lives only in `$RUN/report.md`, outside the repo. The repo's `code-quality.yml` keeps scanner output out of public Actions logs for the same reason.

Write the diff stat and the commit message to the **Hand-off** section and set `status: ready-to-commit` in the header. When the user later opens the PR, put its number in `pr` (and `status: pr-open`) — that is what lets the cleanup find it.

If — and only if — the user later asks you to commit, stage **only** what you changed — never `git add -A` (the working tree may hold unrelated changes): `git add package.json package-lock.json` (+ anything else you deliberately changed). Then **stop and ask again** before pushing / opening a PR (pushing is outward-facing). When asked, open the PR against `dev`.

## Step 9 — Final report

Give the user:
- The bump table (package, old → new per copy, mechanism — update / install / parent bump / override, advisories cleared, exposure, SAFE/REVIEW/BLOCKED, changelog link), **plus, per package, which changelog source you actually read** (releases / CHANGELOG / commit list) and any behaviour change it lists that touches our usage.
- Anything **BLOCKED** (major migration, React 18 peer, ESM-only, patch-package redo) with a short plan, listed separately — these are not done.
- What is **deferred to later batches**, pointing at `$RUN/report.md`.
- Where the reports are (`$RUN`), and that they are deleted automatically once the PR is merged (next run, `/bump-npm-packages cleanup`, or when the user says it's merged).
- Verification results (`npm ci` clean with scripts? audit before → after? tsc? which tests ran? lint? build?).
- The `git diff --stat` scope and a ready-to-use commit message — the user commits it themselves.
- Explicit next step: the tree is ready to commit; commit + push + PR are all pending your go-ahead (you do not commit on your own).
- The `Pills consulted:` line — usually `none — dependency bump`, unless a pill informed the blast-radius check.

---

## Guardrails (do not violate)
- **Node 22 only** — never run npm with another Node major (check `node -v`); a different npm can rewrite the whole lockfile.
- **Conservative by default:** smallest version that clears the advisory on each major line; stay within the current major/minor unless forced higher. Lockfile-only refresh before range bumps, parent bump before overrides.
- **Never `npm audit fix --force`**, never auto-apply a major bump, a React-18-only target, an ESM-only switch, or anything that invalidates a `patches/` file — surface it as BLOCKED with a plan.
- **Research before bumping:** every package gets advisory + changelog + compatibility (peers / engines / ESM / patches) + blast-radius checks. No blind `npm update`.
- **Fix every copy:** verify with `npm ls <pkg> --all`, not just the top-level version.
- **Isolate:** dedicated `chore/` branch off `dev`; never sweep unrelated working-tree changes. If the user later asks you to commit, stage **only** `package.json` + `package-lock.json` (+ anything else you deliberately changed).
- **Verify:** `npm ci` with scripts (deploy-valid lockfile + patch-package) + audit diff + `tsc` + relevant Jest + prod build, with honest results.
- **Public repo:** never put unfixed or deferred advisories in commit messages or PR bodies.
- **Reports:** every run is saved under `.claude/cias-web/npm-bump-reports/` (outside both repos) and deleted only once its PR is merged — or a closed PR's run, when the user says so.
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

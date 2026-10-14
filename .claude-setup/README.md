# CIAS — shared Claude Code setup

The team's [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) setup for working on
CIAS: workspace instructions, subsystem rules, and the slash-command workflows for bug triage,
feature planning, phased implementation with adversarial review, QA and dependency bumps.

CIAS is worked on as a **two-repo workspace** — `cias-api/` and `cias-web/` cloned side by side in one
folder, with Claude started from that folder. The workspace root isn't a git repo, so the shared
setup lives here and `install.sh` copies it into place.

> ⚠️ **This repo is public.** Everything in `.claude-setup/` is published. No secrets, PHI, client
> names or notes, infrastructure addresses, test-account credentials, or details of unfixed security
> issues — ever. Those stay in your local, gitignored `.claude/` folders and the team vault.

## Install

```bash
mkdir CIAS && cd CIAS
git clone git@github.com:Michigan-State-University/cias-api.git
git clone git@github.com:Michigan-State-University/cias-web.git
cias-api/.claude-setup/install.sh     # adds missing files, never overwrites
claude                                # always start Claude from the CIAS/ folder
```

Result:

```
CIAS/
├── cias-api/  cias-web/      # the two repos
├── CLAUDE.md                 # workspace instructions (loads .claude/cias-*/CLAUDE.md)
├── .mcp.json                 # context7 (library docs)
├── cias.code-workspace       # VS Code multi-root workspace
├── .playwright/cli.config.json
└── .claude/
    ├── settings.json         # shared permissions + session-title hook
    ├── commands/ agents/ skills/ hooks/
    ├── cias-api/  cias-web/  # CLAUDE.md + rules/ per repo
    ├── git-and-merge-strategy.md
    ├── onboarding/new-developer-cheatsheet.md   ← start here
    └── qa-scenarios/         # code-validation pass + accounts template
```

**Update** after pulling `cias-api`: `cias-api/.claude-setup/install.sh --overwrite --dry-run` lists
what changed; drop `--dry-run` to apply. `--overwrite` replaces shared files only; your local files
(`settings.local.json`, `jira-tasks/`, plans, notes, `accounts.local.md`) are never touched.

### Mods (status line)

`install.sh` also installs the team's Claude Code mods from `cias-api/.claude-setup/mods/` — a folder
marketplace named `cias-mods`, declared at **local** scope (this workspace only, in
`.claude/settings.local.json`):

| Mod | What it does |
|---|---|
| `interlay-status` | Pings the claude.ai Interlay MCP at session start and every 60 s and pins `Interlay ● connected · N ms` / `○ disconnected · <reason>` under the prompt — you see at a glance whether the workflows will get their knowledge pills. |

The mods are read in place from the repo folder: after a `git pull`, run `/reload-plugins` (or start a
new session). `--skip-mods` skips this step; if you already have a mod of the same name from another
marketplace, the script leaves it and says so. By hand, from the workspace root:

```bash
claude plugin marketplace add "$PWD/cias-api/.claude-setup/mods" --scope local
claude plugin install interlay-status@cias-mods --scope local
```

Tests: `claude plugin test cias-api/.claude-setup/mods/interlay-status` · check:
`claude plugin validate cias-api/.claude-setup/mods/interlay-status`.

## Prerequisites

| Need | For | How |
|---|---|---|
| Claude Code CLI | everything | [install guide](https://docs.claude.com/en/docs/claude-code/setup) — sign in with your HTD claude.ai account |
| **Interlay** connector (claude.ai) | knowledge pills | enable it for your account; in Interlay set **CIAS** as your context-exposed project. Check with `/mcp` — the `mcp__claude_ai_Interlay__*` tools must be listed |
| Node 22 (nvm) | cias-web, context7 (`npx`) | `nvm install 22` — `cias-web/.nvmrc` |
| Ruby per `cias-api/.ruby-version` | cias-api | rvm / rbenv / asdf / mise |
| Python 3 | the session-title hook | macOS ships it |
| `gh` CLI | PR/diff lookups in QA + bump commands | `brew install gh && gh auth login` |
| `playwright-cli` | `/qa-run` | `npm install -g @playwright/cli@latest`, then from `CIAS/`: `playwright-cli install --skills` |

On first start Claude asks you to approve the project MCP server (context7) — approve it.

## Knowledge pills come from Interlay

Curated deep-dives on every CIAS subsystem live in **Interlay** (project CIAS, directories `cias-api`
and `cias-web`), not in this repo. `CLAUDE.md` lists the pill titles; Claude fetches them with
`get_interlay_context` before reading code, and the workflows snapshot what they used into
`<ticket workdir>/interlay-context.md`. When a run spots a pill that's wrong or missing, it writes a
draft to `.claude/knowledge-pills/_inbox/`; `/pills-sync` reviews the drafts and pushes approved new
pills (updates to existing pills go through the Interlay web UI — the MCP is create-only). Without
Interlay everything still runs, from the rules and the code alone.

## Workflows

| Command | Does | Writes to |
|---|---|---|
| `/new-bug <ticket>` | triage: locate code, log-visibility analysis (LogRocket / Sentry / Rails / Sidekiq), verified repro steps, 25-line summary | `.claude/jira-tasks/cias-NNNN-<slug>/` |
| `/fix-bug CIAS-NNNN` | failing test first → minimal fix + regression test, stops before commit | repo working tree |
| `/new-estimate <ticket>` | two-column estimate (traditional vs Claude-assisted), no plan | `…/estimate.md` |
| `/new-feature <ticket>` | plan + estimate, audited by fresh planner → auditor → adjudicator agents | `…/plan-and-estimate.md`, `summary.md` |
| `/run-auditors` | audit rounds 2–3 when `/new-feature` recommends it | same workdir |
| `/create-phases` | PR-sized phases from the confirmed plan | `…/phases/` |
| `/implement-phase` | one phase: code + tests + adversarial code/security review, stops before commit | repo working tree |
| `/qa-scenarios-creator` · `/qa-run` | browser-agent QA scenarios · run one with playwright-cli | `.claude/qa-scenarios/` |
| `/bump-gems` · `/bump-npm-packages` | audited dependency bumps on a `chore/` branch, every changelog read | repo working tree |
| `/pills-sync` | review `_inbox` pill drafts → Interlay | `.claude/knowledge-pills/_inbox/` |

Every workflow **stops before `git commit`** and hands you the diff + a suggested message.

### What the shared `settings.json` blocks or asks about

- **Never readable:** `.env`, Rails keys/credentials, the Google service-account JSON, Cypress env,
  private PEMs, Redis dumps, and the usual home-directory credentials
  (`~/.ssh`, `~/.aws`, `~/.config/gh`, `~/.docker/config.json`, …).
- **Never runs:** destructive DB tasks (`db:drop`, `db:reset`, `db:purge`, `db:schema:load`, …),
  `credentials:show/edit`, `printenv`, pushes to `dev`/`test`/`master` or the production Dokku remotes,
  force-pushes, Dokku `config:*`/`postgres:*` over SSH, destructive or secret-reading `aws` calls,
  `gh repo/release delete`, `npm publish`, `gem push` — and edits to `code-quality.yml`.
- **Asks first:** `git commit`, `git push`, `gh pr create/merge`, Dokku SSH, any `aws`, `curl`/`wget`,
  creating Interlay pills, and every tool of the outward-facing connectors (Slack, Gmail, Jira/Confluence,
  Notion, HubSpot, Google Drive/Docs/Sheets) — nothing PHI-adjacent leaves the machine unprompted.

These are guardrails for what Claude usually runs, **not a security boundary** — a `bash -c '…'` or a
script gets past a command pattern. For real enforcement, turn on the sandbox in your
`settings.local.json` (`"sandbox": { "enabled": true }`): the `Read(…)` denies above are merged into
its OS-level read-deny list (so a sandboxed `aws`, `gh` or `ssh` can't read its credentials either —
run those outside the sandbox). A personal exception goes in `settings.local.json` as an `allow` — but a
project `deny` always wins, so to lift one, run the command yourself with `! <command>`.

### QA accounts

Copy `.claude/qa-scenarios/accounts.local.example.md` to `accounts.local.md` and fill in your own
staging accounts and test phone. Scenarios only ever contain the placeholders.

## Sandbox gotchas (macOS)

- `gh` API calls can fail in the Claude sandbox with `x509: OSStatus -26276` — re-run the read-only
  `gh` command outside the sandbox.
- Sandboxed `npm` failing with *"cache folder contains root-owned files… sudo chown"* is the sandbox
  blocking `~/.npm`, not a permissions problem: `export npm_config_cache="$TMPDIR/npm-cache"`. Never chown.
- RSpec needs `cias-api/.env`; if your sandbox denies reading it, specs have to run outside the sandbox.
- The Claude shell may not load your shell profile — if `ruby -v` / `node -v` show the wrong version,
  call `bundle` / `npm` through your version manager's wrapper or shim.

## Personal settings

Put your own permission allows, model choice etc. in `.claude/settings.local.json` (never shared).
To turn off the session-title hook (it makes one small Haiku call on a session's first prompt), set
`"disableAllHooks": true` there.

## Changing the shared setup

Edit the files under `cias-api/.claude-setup/workspace/` (`dot-claude/` = the workspace `.claude/`;
it can't be called `.claude` inside cias-api, which gitignores that name) or `cias-api/.claude-setup/mods/`
(run `claude plugin test` and `claude plugin validate` on a changed mod) and open a PR to `dev` like
any other change. After it merges, everyone runs `install.sh --overwrite`. Before committing, re-read
the public-repo warning at the top.

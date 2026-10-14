---
name: pills-sync
description: Review knowledge-pill drafts in .claude/knowledge-pills/_inbox/ and get the approved ones into Interlay — push NEW pills via the Interlay MCP, and prepare paste-ready updated bodies for EXISTING pills (the MCP is create-only, so those go through the Interlay Web UI).
argument-hint: "[status | review | push]  (no arg = full flow: review → push)"
when_to_use: After a /new-feature, /new-bug or /fix-bug run leaves drafts in _inbox/.
---

# /pills-sync — pill drafts ⇄ Interlay

Knowledge pills live in **Interlay** (project CIAS, directories `cias-api` and `cias-web`); there are no local pill copies. Agent runs harvest drift/gap observations as **drafts** in `.claude/knowledge-pills/_inbox/`. This command is the review gate between those drafts and Interlay:

```
_inbox/ drafts ──(you review)──► new pill      ──(MCP create_knowledge_pills)──► Interlay
                              └► updated pill ──(paste-ready file, Web UI)─────► Interlay
```

Mode from `$ARGUMENTS`: `status` = inventory only · `review` = Phase 2 only · `push` = Phase 3 only · empty = full flow.

## Hard constraints (read first)

- **The Interlay MCP is create-only.** `create_knowledge_pills` exists; there is no update, list or delete tool. Changes to an existing pill MUST go through the Interlay Web UI — this command prepares the updated body, a human pastes it.
- **Pushing is outward-facing.** Never call `create_knowledge_pills` without showing the user exactly what will be pushed (title, target directory, knowledge_type, content preview) and getting explicit confirmation in this conversation.
- **Never push a draft as-is.** A draft is evidence + a suggested change; it must first be turned into a full pill (new) or a full updated body (existing) and approved in Phase 2.
- **Never invent directory UUIDs.** Resolve them fresh via `get_interlay_info` every run (its snapshot must not be cached across sessions).
- **A duplicate title fails the entire batch** (transactional). Recover per Phase 3 — don't retry blindly, never rename a pill just to force a push.
- **Nothing sensitive goes into a pill:** no PHI, credentials, hostnames/IPs of client systems, or details of unfixed security issues. Pills describe how the code works.

## Phase 0 — Orient

1. Call `mcp__claude_ai_Interlay__get_interlay_info`.
2. Verify `current_project.name` is **CIAS** — if not, stop and tell the user to switch their context-exposed project in Interlay.
3. From `directory_structure`, resolve the UUIDs of the `cias-api` and `cias-web` directories (children of "CIAS Project Knowledge Pills") and note whether you have `permission: manage` on each. No manage → Phases 0–2 still run; Phase 3 stops at the confirmation step and hands the files to someone with manage rights.

## Phase 1 — Inventory

Show a status table of `_inbox/*.md`:
- `pending-review` drafts, counted by `type` (drift / gap / new-knowledge) and `target-pill`.
- `approved` items waiting to be pushed: `_inbox/to-push/*.md` (new pills) and `_inbox/web-ui-updates/*.md` (updated bodies not yet confirmed as pasted).

In `status` mode, stop here.

## Phase 2 — Review drafts (interactive)

For each pending draft (skip in `push` mode), grouping drafts that target the same pill:

1. **Re-check the evidence against the code** (Read/Grep the cited paths). A draft whose claim no longer holds → propose Discard.
2. **Fetch the current pill** when `target-pill` names one: call `get_interlay_context` with the pill title + the draft's topic. If no matching pill comes back, treat the draft as `target-pill: new`.
3. Show a compact summary: title · type · target pill · evidence (verified / stale) · suggested change.
4. Ask the user (AskUserQuestion, batch related drafts): **Apply** / **Discard** / **Keep pending**.
5. On **Apply**:
   - **Existing pill** → write the **complete updated pill body** to `_inbox/web-ui-updates/<kebab-title>.md`: fold the change into the right section, keep the pill's voice and `(src: …)` citation style, and add a short header comment listing what changed and why (strip that header before pasting).
   - **New pill** (`target-pill: new`) → write the full pill to `_inbox/to-push/<repo>-<kebab-title>.md` in the house shape: `# Title`, `**When to load:**`, `## Quick Summary`, "Answers questions like", sections with `(src: …)` citations. Frontmatter: `directory: cias-api | cias-web`, `knowledge_type: context`. Then offer to add a row to the pill tables in the workspace `CLAUDE.md` and `.claude/skills/new-feature/reference/knowledge-pills-index.md` (these are shared files — the change goes into `cias-api/.claude-setup/` via a PR).
   - Move the draft to `_inbox/applied/` and set `status: applied` (audit trail).
6. On **Discard** → move to `_inbox/discarded/`, `status: discarded`.
7. On **Keep pending** → leave in place.

## Phase 3 — Push to Interlay

1. **New pills** = `_inbox/to-push/*.md`. Pre-push checks per pill:
   - Content ≤ 50,000 chars (over → warn and skip; suggest splitting).
   - **Secret/PHI scrub**: scan for PEM blocks (`-----BEGIN`), `password\s*[:=]`, secret-prefixed tokens (`sk-`, `ghp_`, `xoxb-`, `glpat-`, `AKIA`), base64/hex runs ≥ 32 chars, IP addresses, email addresses other than placeholders. A hit means stop that pill and warn the user.
   - `knowledge_type: context` (the only curated type; meeting types are machine-generated).
2. Show the push list (title → directory → knowledge_type → first lines of content) and **get explicit confirmation**.
3. Call `mcp__claude_ai_Interlay__create_knowledge_pills` with the batch: `title` = the pill's H1 text, `content` = the full markdown (without frontmatter), `knowledge_type: "context"`, `directory_id` = the UUID resolved in Phase 0. **Omit `review_due_date`.**
   - **On duplicate-title failure**: the error names the failing item. That pill already exists — move its file to `_inbox/web-ui-updates/` (it becomes an update, not a create), remove it from the batch, retry the remainder.
4. On success, move each pushed file to `_inbox/pushed/` and add the returned `id` + date to its frontmatter. Embeddings are generated asynchronously — new pills become searchable shortly after, not instantly.
5. **Updated pills** = `_inbox/web-ui-updates/*.md`: output a checklist — pill title, Interlay directory, file path — and tell the user to paste each body into the Interlay Web UI. When the user confirms a pill was updated, move its file to `_inbox/pushed/`.

## Phase 4 — Report

One table: drafts applied / discarded / still pending · new pills pushed (with Interlay ids) · updates awaiting Web UI paste. End with the next natural step (e.g. "2 drafts still pending", "3 updates need a Web UI paste"). Finish with the `Pills consulted:` line — the existing pills you read to judge the drafts.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.

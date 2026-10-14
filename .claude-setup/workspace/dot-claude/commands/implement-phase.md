---
name: implement-phase
description: Implement one phase of a phased /new-feature plan — preflight-checks dependencies and git state, loads the phase file + knowledge pills, writes the code and tests on the ticket's feature branch, verifies acceptance criteria, then runs adversarial review rounds (fresh code-review + conditional security-review, ruled on by a separate adjudicator) up to --max-review-rounds, default 1 and absolute cap 3, before flipping phase status and STOPPING short of the commit (the developer commits manually).
argument-hint: "[CIAS-NNNN or slug] [phase number] [--max-review-rounds <N>] [--review-only [<git range>]]  (no number = next runnable phase; default 1 review round)"
when_to_use: After /create-phases produced phases for a ticket. One phase per invocation, ideally in a fresh session.
---

# /implement-phase — execute one phase of a phased plan

The phase file is the **contract**: self-contained spec, produced from a confirmed + sanity-audited plan. Your job is to implement exactly it — code and tests — to the repo's conventions, verify its acceptance criteria, and leave an honest status behind. One phase per invocation.

## Modes

- **Full (default)** — Steps 0 → 6. Implement, verify, review, close out.
- **`--max-review-rounds <N>`** — the ceiling on Step 5's review rounds. **Default `1`.** Combines with either mode. `1` means one round runs and the loop then stops *regardless of what it found* — blocking findings are still fixed, recorded in `## Remaining`, and left for the developer to decide on, rather than automatically buying another round. Raise it (`--max-review-rounds 2`, `3`) when you want the loop to keep going while blocking findings survive. Values above **3** are clamped to 3 — see the cap in 5.5 for why a fourth round is the wrong instrument. `0` skips Step 5 entirely and is **only** legitimate for a scratch/spike phase nobody will merge; say so out loud in the close-out if used.
- **`--review-only [<git range>]`** — Steps 0 → 1 (preflight only, see below) → 2 → **5** → 6. Step 2 still runs: the reviewers and the adjudicator need the pills and `summary.md`'s core decisions, since 5.3 rules a finding that contradicts a decided trade-off as a `reject`. For a phase that was implemented **by hand** or in an earlier session, so the adversarial review loop can still run over it. Skips Step 3 (implement) and Step 4 (verify) entirely — do **not** re-implement work items that already exist, and do not re-derive acceptance criteria you did not just satisfy.

  In review-only mode: skip Step 1's dependency gate (the code exists; the gate is moot) but still run its git-state check, and **do not flip the phase status** — you didn't implement or verify it, so promoting it isn't yours to do. Report the review outcome, append the round block, and if blocking findings survive, add them to `## Remaining` and say plainly that the phase must not be marked `done` until they're closed.

## Step 0 — Resolve

1. From `$ARGUMENTS`: ticket/slug → glob `.claude/jira-tasks/` for `<WORKDIR>`; phase number → `phases/phase-<N>-*.md`. Also parse `--max-review-rounds <N>` (default **1**, clamped to 3) and `--review-only [<range>]`; **state the resolved round ceiling out loud before Step 5 starts**, so the developer knows what they are getting.
2. No phase number → pick the **next runnable** phase: the lowest-numbered `pending` phase whose `depends_on` are all `done`. If a phase is `in-progress`, offer to resume it instead (read its `## Implementation notes` first).
3. Required: `phases.md` (plan `status: phased`) + the phase file. Missing → stop; point at `/create-phases`.

## Step 1 — Preflight gates

1. **Dependencies**: every phase in `depends_on` has `status: done`. Not met → stop. Only proceed on an explicit developer override, recorded in the phase file (`Override — <date>: started with phase <M> not done`).
2. **Git state**, per repo in the phase's `repos` (run git inside `cias-api/` / `cias-web/` — separate repos):
   - `git status` — unrelated uncommitted changes → warn and let the developer decide before touching anything.
   - Branch: reuse the ticket's existing feature branch if one exists (`git branch --list '*<nnnn>*'`); otherwise create `feature/cias-<NNNN>-<slug>` from `dev` (see `.claude/git-and-merge-strategy.md` for the promotion flow). Creating/switching branches is fine; **committing is not** (see hard rules).
3. Flip status `pending → in-progress` in both the phase file and the `phases.md` index row.

## Step 2 — Load context (pills before code)

1. The phase file is the spec — read it fully.
2. Load the knowledge pills for the subsystems this phase touches — from `<WORKDIR>/interlay-context.md` (the planning snapshot), plus `mcp__claude_ai_Interlay__get_interlay_context` for any pill it lacks (titles in the workspace `CLAUDE.md` / `.claude/skills/new-feature/reference/knowledge-pills-index.md`). Prefer a fresh Interlay fetch when the snapshot is more than a few weeks old. Also load the matching rule files (`.claude/cias-api/rules/`, `.claude/cias-web/rules/`) per the repo's sub-CLAUDE.md.
3. Skim `<WORKDIR>/summary.md` for the feature's core decisions — the phase must not contradict them.

## Step 3 — Implement

- Work through the phase's **Work items** in order, following repo conventions (JSON:API serializer shape, CanCanCan abilities, Redux 6-file module pattern, i18n messages, factory updates — whatever the items name).
- **Tests are work items too**: write the phase's listed specs/Jest tests alongside the code, never "later".
- **Scope guard**: the phase does not grow. A small necessity the phase missed (≲ an hour, unavoidable to make the phase work) → do it and record it under `## Deviations` in the phase file. Anything material → stop and surface it; new scope goes through the plan (Revision log, possibly `/run-auditors`) before any phase absorbs it.
- A wrong fact in the phase file (path moved, model renamed) → implement against reality, record the deviation, and fix the same fact in any later `pending` phase files it also affects.

## Step 4 — Verify

1. **Size every long-running gate before you start it — and check whether it's a local gate at all.** When a criterion names a *full* suite rather than specific paths, estimate the cost first (`grep -rhoE "^\s*(it|specify|scenario)[ (]" spec/ | wc -l`, or a previous run's timing) and check how CI runs it. **cias-api's full `bundle exec rspec` is ~4300 examples and takes ~4-5 hours serially on a laptop — but CI never runs it that way**: `.github/workflows/ci.yml` splits every spec file into `TEST_BATCH_COUNT` chunks across a GitHub Actions matrix. A full serial local run is therefore the wrong gate; run the feature-relevant suites locally and let the full suite land on the PR. If a phase file's criteria demand the full local run anyway, say so **up front**, propose rewording it, and let the developer choose — measured 2026-08-05, CIAS-4191 phase 4, where discovering this at close-out turned an otherwise-complete phase into an unmet criterion.
2. Run the phase's tests plus lint, per repo: `bundle exec rspec <paths>` + `bundle exec rubocop` (cias-api); `npm test -- <paths>` + `npm run lint` (cias-web).
3. Walk the phase's **Acceptance criteria** one by one — mark each met/unmet with evidence (test output, manual check). Report failures faithfully; never gloss.
4. **Any QA/verification harness you write must be re-runnable a row at a time.** Give it row ids and argument selection so fixing one case re-drives only that case, never the whole fixture — an all-or-nothing harness turns each fix into a full re-run, and that is where verification time actually goes.

## Step 5 — Adversarial review loop (fresh agents; you orchestrate, you do not review)

The planning stages get five independent adversarial passes (`/new-feature` ×3, `/run-auditors` ×2 rounds, `/create-phases` ×1). Without this step the **code** gets none — the plan is cheap to fix and the code isn't, so the asymmetry runs the wrong way. This closes it with the same mechanics as `/run-auditors`: fresh contexts, files on disk as the only channel, a separate adjudicator, computed signals, hard cap.

**You are the orchestrator here.** You wrote the code, which makes you the worst possible judge of whether a criticism of it is fair — never rule on a finding yourself, and never argue with the adjudicator. Apply its verdicts mechanically; disagreements go to the developer as notes.

**The three review agents live in `.claude/agents/`** — `code-reviewer`, `security-reviewer`,
`review-adjudicator`. They carry the standing brief (verify by running rather than reasoning; restore
anything you mutate and confirm with `shasum`; a clean verdict is a useful outcome; don't manufacture
findings or inflate severity) and the codebase's known review traps. Each fetches the knowledge pills it needs from Interlay itself; pass it
`<WORKDIR>/interlay-context.md` so it starts from the same snapshot. Keep your per-round prompt to what is
actually diff-specific — retyping the standing instructions is how they drift between rounds.

Artifacts live in `<WORKDIR>/reviews/` as `phase-<N>-code-review-r<M>.md`, `phase-<N>-security-review-r<M>.md`, `phase-<N>-adjudication-r<M>.md`. Create the dir if absent.

### 5.1 — Establish the diff under review

**State the exact range you hand the reviewers, every time.** A review of the wrong diff is worse than no review, and it is the single easiest thing to get wrong here.

**Full mode**: the phase's work is the **uncommitted** diff, since this command never commits — `git diff HEAD` per repo in the phase's `repos`, plus staged changes and untracked files the phase added (`git status --short`). If the developer committed mid-phase, widen to `git diff <base>..HEAD` where `<base>` is the commit the phase started from (its `## Implementation notes` records it).

**Review-only mode**, resolved in this order:

1. An explicit range in `$ARGUMENTS` (`--review-only bcb23e00..f3763c35`) — use it verbatim, no inference.
2. Otherwise, if the working tree has staged/unstaged/untracked changes, review those — a hand-implemented phase awaiting its commit is already in exactly the right shape.
3. Otherwise, find the phase's own commit by subject (`git log --oneline --grep "Phase <N>"`) and review that commit alone.
4. Otherwise, stop and ask. Never guess a range.

Then **check the range actually matches the phase** before spending agents on it: list the files it touches against the phase file's work items. If it spans more than one phase, or misses items the phase claims, say so and let the developer narrow it — reviewing phase 3's diff under a phase-1 heading produces findings nobody can act on. Watch for a stray unstaged edit to an earlier phase's file; exclude it or name it explicitly.

### 5.2 — Round 1: one or two dimensions, in parallel

**Correctness & quality — always.** Spawn the **`code-reviewer`** agent (`.claude/agents/code-reviewer.md`), which carries the standing brief and invokes the `code-review` skill itself. Your prompt supplies only what is diff-specific: the rendered diff, the phase contract, `summary.md`, and the questions you are least sure about. Effort: `medium` for a phase under ~5 files, `high` for anything larger or touching a shared component. Do **not** pass `--fix` — fixes are applied after adjudication, not before.

**Security & PHI — conditional.** Spawn the **`security-reviewer`** agent (`.claude/agents/security-reviewer.md`), which carries this codebase's PHI boundary, logstop's real limits and the Sentry trap, and invokes the `security-review` skill itself. Do this **when the diff touches any of**: encryption/Lockbox, logging or Sentry payloads, abilities/authorization, strong params, raw SQL, file handling, or an outbound HTTP call. Those are where this codebase's traps live and they're non-obvious — a key or method whose name promises filtering is not proof that anything is filtered. A frontend picker or a styling phase gets nothing useful from a security pass, so don't spend one. Independent of phases, run it **once over the whole branch before the PR** regardless — that's the backstop for anything the per-phase triggers missed.

Both dimensions are independent, so run them concurrently when both apply (unlike the planning pipeline, where each stage consumes the previous). Write each dimension's findings to its file before continuing. Reviewers must cover the **tests as well as the code** — a tautological or wrong-assertion spec is a finding, and it's one that self-verification structurally cannot catch.

### 5.3 — Adjudicate (a fresh agent, every round)

Spawn a **new** **`review-adjudicator`** agent (`.claude/agents/review-adjudicator.md`) at effort **`xhigh`** — pinned, not inherited. Do not cheapen it because the session is running lower or because the round looks like bookkeeping: this is the highest-judgment task in the workflow and the only one that can overturn a reviewer, and it is far cheaper to over-spend here than to act on a wrong ruling. Measured on CIAS-4157 phase 5: adjudicators promoted a `nit` to `blocking`, rejected a finding outright, overruled an over-reaching claim *inside* an otherwise-confirmed finding, found a reachability path neither reviewer had, and caught ~10 green specs that were documenting the wrong behaviour as correct. None of that is mechanical.

Give it the workdir, the phase file, today's date, the round number, both review files, and the diff. It rules on **every** finding and writes `phase-<N>-adjudication-r<M>.md`:

- **Verdict** — `CONFIRMED` / `PARTIALLY-CONFIRMED` / `FALSE-POSITIVE`, each with evidence re-derived from the code, not taken on the reviewer's word. A `FALSE-POSITIVE` ruling is a useful outcome; reviewers over-reach, and momentum-confirming is the live failure mode by round 2.
- **Severity** — `blocking` (correctness bug, PHI/security exposure, data loss, silent failure) / `should-fix` / `nit`.
- **Disposition** — and this is the part planning doesn't have:
  - `fix-now` — inside the phase's contract, fix it in this phase.
  - `defer-to-plan` — real, but it's **new scope**. It goes to the plan's `## Revision log` and the phase file's `## Review deferrals`, never silently absorbed. Same boundary as the Step 3 scope guard.
  - `pre-existing` — the diff didn't introduce it. Record it, don't fix it here; a separate ticket if it matters.
  - `reject` — false positive.

It must also flag anything where a finding **contradicts the confirmed plan** (`summary.md`'s core decisions) — the plan wins, and a reviewer pushing against a decided trade-off is a `reject` with the decision cited.

### 5.4 — Apply, re-verify, record

1. Apply every `fix-now` finding. Nothing else.
2. **Re-run the phase's tests and lint** — a fix that breaks a spec is the most common way this loop makes things worse.
3. Append a `## Review round <M>` block to the phase file: findings by verdict and severity, what you fixed, what was deferred and where it went, plus the signals line.

### 5.4b — Fix verification (blocking fixes only, and it is NOT a review round)

**Trigger: you applied a `fix-now` verdict on a finding ruled `blocking`.** Then, before Step 5.5's
continuation test, spend **one** fresh **`code-reviewer`** agent on verifying those fixes — and only those.

Why this exists as a separate instrument: `--max-review-rounds` governs *discovery* (broad, expensive,
benefits from fresh eyes on everything). Verifying that an ordered fix landed correctly is a different job —
narrow, cheap, mechanical, and bounded by a list you already have. Conflating them forces a choice between
paying for a full round and shipping blocking fixes nobody looked at, and at the default ceiling of 1 that
choice always resolves the wrong way: **the highest-risk change in the phase is the one change guaranteed to
go unreviewed.** A blocking fix is, by construction, a behavioural change to code that failed review once
already; and fixes are a demonstrated defect source in their own right — a reviewer's *proposed* fix has been
caught introducing a fresh bug, so the fix needs checking even when the finding was right.

Because it is bounded, **it does not count against `--max-review-rounds`** and it is not optional at the
default ceiling. It does not run for a round that produced only `should-fix` and `nit` items — those are
local and the re-run in 5.4 already covers them.

Give the agent, and nothing wider:

1. The **ordered fix list** from the adjudication, numbered.
2. The **delta** — the diff of the phase snapshot before the fixes against the current state (`git diff` of
   the rendered round files). Not the whole phase diff.
3. The adjudication and any earlier review files, marked **authoritative and settled** — re-opening a ruling
   needs positive new evidence, not a differing opinion.

It answers three bounded questions per fix, and nothing else:

- **Did it land**, and does it do what was *ordered* — not merely something plausible in the vicinity?
- **Is it falsifiable** — does a test actually fail without it? (A fix pinned by a test that cannot fail is
  the single most common way this loop produces false confidence.)
- **Did it introduce anything new** in the lines it touched — especially in shared code, where a fix aimed at
  this phase changes a path the phase does not own.

Tell it plainly that a clean verdict is the expected outcome and that it must not manufacture findings to
justify the pass.

**Ruling and escalation.** If it reports nothing, record one line in the `## Review round <M>` block and carry
on to 5.5. If it reports a **regression introduced by a fix**, that is a new blocking finding: adjudicate it
(5.3) and fix it. Do **not** silently spawn a further discovery round — if the fixes to the fixes are still
landing badly, say so to the developer and let them decide, exactly as at the ceiling in 5.5.

### 5.5 — Signals & continuation

**The ceiling is `--max-review-rounds`, default `1`.** Compute for the round just finished:

- `confirmed_blocking` — findings ruled `CONFIRMED`/`PARTIALLY-CONFIRMED` **and** severity `blocking`.

**Run another round only when BOTH hold: `confirmed_blocking ≥ 1` AND rounds run so far < the ceiling.** Not "when anything was fixed" — reviewers always find *something*, so a fixes-applied trigger makes the cap the stopping rule instead of convergence, which is exactly the failure `/run-auditors` was designed to avoid. A round that produced only `should-fix` and `nit` items is done: those fixes are small, local, and re-verified by the tests you just re-ran.

The justification for continuing at all is narrow: a **blocking** fix is a real behavioural change to code nobody has reviewed. That earns one fresh pass. Cosmetic churn doesn't.

**At the default ceiling of 1, that second condition is what stops you.** One round runs; you apply its `fix-now` verdicts, re-run the tests, and **stop** — even with `confirmed_blocking ≥ 1`. This is deliberate: the fixes for a blocking finding are the highest-value part of the loop and they are cheap, while each further round costs three fresh agents and a large share of the turn's tokens for a diminishing return. So when you stop at the ceiling with blocking findings open, do all of this and none of it silently:

1. Apply the `fix-now` verdicts and re-verify, exactly as in 5.4 — **the ceiling stops *reviewing*, never *fixing*.**
2. Put the surviving blocking findings in `## Remaining` with their adjudicated verdict, severity and disposition.
3. Say plainly in the close-out that the ceiling was reached with `confirmed_blocking = <n>` open, and exactly how far the fixes were checked: **5.4b verified that the ordered fixes landed and are falsifiable, which is not the same as a fresh pass over the phase.** Name what 5.4b did not look at — everything outside the lines the fixes touched. The developer cannot weigh the residual risk if you blur those two things together.
4. Name the exact command that continues it: `/implement-phase <key> <N> --review-only --max-review-rounds <ceiling + 1>`. Whether another round is worth its cost is the developer's judgement, not yours.

The phase still cannot reach `done` — see the teeth below. Reaching the ceiling is not a discharge.

Round 2+ re-runs `code-review` on the **new** diff, and re-runs `security-review` only if a fix touched one of 5.2's trigger surfaces. Tell each fresh reviewer which round it is and what changed since the last one — the earlier rounds' files are on disk, so it doesn't re-file settled findings.

**Hand rounds 2+ a *delta*, not the whole diff again.** Render the phase diff to a file at the start of every round (`git diff -- <paths>` plus `cat` of each untracked file), keep the previous round's copy, and give the reviewers `diff -u <round-N-1>.diff <round-N>.diff` as their **first** input alongside the full diff for context. Re-reading the entire phase every round is the single largest avoidable cost in this loop, and it is also a *correctness* win: a reviewer looking at 380 changed lines checks whether the fixes did what was ordered, while one looking at 1100 lines drifts back into re-sweeping settled ground — exactly what the round's scope forbids. State in the prompt which questions earlier rounds **settled with runtime evidence** and that re-opening one needs positive new evidence.

Also tell them what to verify rather than re-derive: a fix-verification round's job is "did these N named items land, do they do what was ordered, and is each one falsifiable" — a table, not a hunt. Keep reviewer effort at `high` when the round exists because of a blocking finding (which is the only reason a round 2 exists at all); `medium` is enough if you are only confirming that a list of `should-fix` items landed.

**Absolute cap: 3 rounds, even if a larger `--max-review-rounds` is passed — and round 3 is an escalation, not a grind.** If round 3 *still* yields `confirmed_blocking > 0`, stop: the phase **stays `in-progress`**, those findings go in `## Remaining`, and you tell the developer plainly that three independent passes kept finding blocking defects in the same phase. That is a signal about the phase, not about the reviewers — the plan's assumptions for it are probably wrong, and it belongs back in the plan (Revision log, possibly `/run-auditors`) rather than in a fourth review round. Same exit as `/run-auditors`' `unstable-needs-rescope`.

A phase can never reach `done` with a confirmed blocking finding open. That's the teeth.

## Step 6 — Close out

1. **Status, honestly**: all criteria met + tests green + no outstanding `confirmed_blocking` review findings → `done` (phase file + index row). Anything unmet → stays `in-progress` with a `## Remaining` list; never mark done on red. **In review-only mode, leave the status untouched** — you neither implemented nor verified the phase, so it isn't yours to promote; just record the review outcome and any `## Remaining`.
2. Append `## Implementation notes` to the phase file: files touched, deviations, decisions made, anything the next phase's session needs to know.
3. **Pill feedback**: implementation is where drift really surfaces. Pill-vs-code contradictions, uncovered subsystems, verified non-obvious facts → append to `<WORKDIR>/pill-feedback.md` (standard entry format, `found-by: implementer`), then harvest new entries to `.claude/knowledge-pills/_inbox/` per the harvest rules in `.claude/skills/new-feature/SKILL.md` Step 5.5 (dedupe included — not to be confused with this command's Step 5.5).
4. **Hand the commit to the developer**: show `git diff --stat` per touched repo + a suggested commit message (e.g. `CIAS-NNNN: <phase name> (phase <N>/<total>)`). Do **not** commit.
5. **Report the review loop in ≤3 lines**: rounds run · findings by verdict (`<c>` confirmed / `<p>` partial / `<fp>` false-positive) · the single most important thing it caught and fixed · anything deferred to the plan · anything left in `## Remaining`.
6. Point at the next step: the next runnable phase (`/implement-phase <key>`), or — after the final phase — the QA checklist in that phase, `/qa-scenarios-creator` / the `qa-suite-planner` agent for browser-agent scenarios, and `/pills-sync` if `_inbox/` gained drafts.
7. End with the `Pills consulted:` line — yours plus what the review agents and the adjudicator report (on top of the ≤3-line review summary).

## Hard rules

- **NEVER `git commit`, `git push`, or open a PR** — the developer commits manually, always. End with the diff and the suggested message.
- One phase per invocation; the phase file is the contract — no silent scope growth.
- Never mark a phase `done` with failing tests, unmet criteria, or an outstanding confirmed-blocking review finding — an honest `in-progress` + `## Remaining` beats a false green.
- Update statuses in BOTH the phase file and the `phases.md` index — they must never disagree.
- **Never skip Step 5's round 1, and never review your own work.** The review agents are fresh contexts and the adjudicator is a separate one; you apply verdicts, you don't argue them. Skipping the loop because "the phase is small" is exactly the case where a silent-zero slips through. Rounds beyond the first are earned by blocking findings **and** by an explicit `--max-review-rounds`, never automatic — one clean round is a complete outcome, not a shortcut, and at the default ceiling one round is all you get.
- **Review fixes are fixes, not features.** A confirmed finding that needs new scope is `defer-to-plan` → plan Revision log + phase `## Review deferrals`. The loop must never become a second planning stage.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.

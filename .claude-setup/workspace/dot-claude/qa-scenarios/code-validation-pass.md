# Code-Validation Pass — for browser-agent QA results

A browser agent (Claude in Chrome, or `/qa-run` via playwright-cli) running CIAS scenarios is **reliable at reporting what it
saw on screen**, but it tends to **invent plausible-but-wrong explanations** for anything it couldn't
do — "feature absent from staging", "needs exactly 1 remaining type", "TLFB not in this env". Those
explanations are guesses, not facts.

**Rule: never trust a PARTIAL / FAIL / NOT-TESTABLE reasoning until it has been checked against the
code.** Every such item gets one of three outcomes:

- **CONFIRMED defect** — code shows the behavior is genuinely wrong → keep as FAIL, file it.
- **FALSE ALARM (test-spec error)** — the *expectation* was wrong; the app is correct → reclassify to
  PASS and fix the scenario step so it doesn't re-flag.
- **NEEDS RE-TEST** — the agent's observation was inconclusive (wrong place, chooser not opened, wrong
  config) → the item wasn't really exercised; re-run it properly. Not a defect.

PASS steps are usually trustworthy and don't need this pass — focus effort on the non-PASS items.

## How to run the pass (per non-PASS item)

1. **Restate the claim and the expectation** the step asserted (the "PASS if …" condition).
2. **Find the authoritative code** — gating conditions, enums/wire values, validations, disabled-state
   logic, async side effects. Prefer the files the knowledge pills cite (`(src: …)`). Backend in
   `cias-api`, frontend in `cias-web`.
3. **Decide the outcome** (CONFIRMED / FALSE ALARM / NEEDS RE-TEST) with a `file:line` citation.
4. **Apply the fix:** update `results/<feature>-results.md` (reclassify + cite), and if it was a
   test-spec error, correct the step in `<feature>.md` so future runs are accurate.

Run independent items in parallel (one focused agent each) — it's faster and keeps each investigation
scoped.

## Checklist of common false-explanation patterns (seen in real runs)

- **"Feature absent from staging / this environment"** → is it actually gated by a per-record DB flag,
  an env var, a license/permission, or intervention status? (e.g. CAT-MH is gated by
  `intervention.is_access_revoked`, default `true` — not a deployment gap.)
- **"X toggle/field not found in the settings panel"** → does X actually live there? Many settings are
  intervention-level or edited inline on a tile, not in the session Settings panel. (estimated-time =
  session tile; sharing + sensitive-data = intervention-level.)
- **"Control not in the DOM"** → is it behind a click (a chooser/menu/modal that must be opened first)?
  The agent may have scanned the static DOM without opening it. (TLFB only renders inside the opened
  add-question/group chooser, and only for Classic sessions.)
- **"Skip/auto behavior needs N items" / invented thresholds** → read the actual condition; the agent
  often fabricates the rule. (Modal-skip fires when ALL non-Classic types are unavailable, not at a
  count.)
- **"Handle/affordance present, so it's a bug"** → the guard may be enforced elsewhere (a disabled
  droppable, a server-side filter, a validation) rather than by hiding the affordance. (RA tile keeps a
  drag handle but is in a drop-disabled, isolated droppable and is filtered from the reorder payload.)
- **Wrong wire value / error code / reason string** → confirm the exact literal in code + locale files;
  the agent may report a method name, a client-derived string, or an approximate code.

## Reusable agent prompt (paste into an Agent / Task, one per item)

> You are a read-only code validator for a CIAS browser-agent QA result. You do NOT edit app code.
> Repos (relative to the workspace root, your cwd): backend `cias-api/`, frontend `cias-web/`. Prefer
> files cited by the knowledge pills — fetch the relevant pill with `mcp__claude_ai_Interlay__get_interlay_context`
> (name the pill title from the workspace `CLAUDE.md`), or read `.claude/qa-scenarios/<feature>.pills.md` if it exists.
>
> The QA scenario step asserted: «PASTE the "PASS if …" expectation». The browser agent reported:
> «PASTE the agent's observation + its stated reason». 
>
> Determine, with `file:line` citations, what the code actually does for this behavior — the exact
> gating condition / enum / validation / disabled-state / async side effect involved. Then classify the
> result as exactly one of: (a) CONFIRMED DEFECT (code shows real wrong behavior), (b) FALSE ALARM —
> the test expectation was wrong and the app is correct (state the corrected expectation), or (c) NEEDS
> RE-TEST — the observation was inconclusive (say exactly how to exercise it properly). Quote the code
> that proves your verdict. Do not guess; if the code is ambiguous, say so and say what would resolve
> it.

## Where results go

- Reclassified results + citations → `results/<feature>-results.md` (one section per scenario).
- Corrected expectations → the relevant step in `<feature>.md`.

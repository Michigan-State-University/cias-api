# QA accounts — LOCAL ONLY

Copy this file to `.claude/qa-scenarios/accounts.local.md` and fill it in with your own staging
(`test.cias.app`) accounts. `/qa-run`, `/qa-scenarios-creator` and the QA agents resolve the
placeholders in scenario files from it.

**Never commit the filled-in file, and never copy its values into a scenario, a results file, a PR
or a ticket.** Scenario files use the placeholders only.

| Placeholder | Value | Notes |
|---|---|---|
| `<RESEARCHER_A>` | `you+researcher@example.com` / `<password>` | owner account for most scenarios |
| `<RESEARCHER_B>` | `you+researcher2@example.com` / `<password>` | second owner, for scenarios run in parallel |
| `<PARTICIPANT>` | `you+participant@example.com` / `<password>` | to generate participant answers |
| `<TEST_PHONE>` | `+1…` | receives the real SMS sent by [HUMAN-VERIFIED] steps |
| `<TEST_EMAIL>` | `you+qa@example.com` | receives report / notification emails |

Playwright auth-state files (`.playwright/auth-<alias>.json`) carry the 30-day 2FA trust cookie for
these accounts — they also stay local.

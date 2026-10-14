# CIAS API — Claude Instructions

Rails 7 / Ruby 3.3 backend for the CIAS platform. Lives at `cias-api/` in this workspace; this file is loaded when working on backend tasks (see workspace [CLAUDE.md](../../CLAUDE.md)).

**Repo root:** `cias-api/` (separate git repo — run `git` commands from inside that directory).

## Domain & Architecture
@.claude/cias-api/rules/domain_model.md
@.claude/cias-api/rules/database_patterns.md
@.claude/cias-api/rules/encryption_security.md

## Patterns & Conventions
@.claude/cias-api/rules/service_objects.md
@.claude/cias-api/rules/api_controllers.md
@.claude/cias-api/rules/auth_roles.md
@.claude/cias-api/rules/sidekiq.md

## Third-Party Integrations
@.claude/cias-api/rules/integrations.md

## Local working dirs (workspace-relative, never committed)

These hold your own notes and may reference production data or open security issues — they stay on your machine. Create them as needed:

- Plans & RFCs: `.claude/cias-api/plans/` (grouped by feature or Jira ticket)
- Jira scratchpads: `.claude/cias-api/jira-tasks/`
- Free-form notes: `.claude/cias-api/notes/`
- Security scan reports: `.claude/cias-api/scan-reports/`
- Backlog items (tech debt / HIPAA): `.claude/cias-api/backlog/`
- Saved diagnostic queries: `.claude/cias-api/queries/`
- Manual-test scripts: `.claude/cias-api/testing/`

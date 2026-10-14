# CIAS — New Developer Cheatsheet

> **Owner:** TODO · **Last verified:** 2026-10-09
> One page for your first weeks on CIAS. This page holds **no secrets**: passwords, keys and `.env` values are in **TODO: password manager vault name**. If something here is wrong, fix it and bump the date.

---

## 1. What CIAS is (30 seconds)

**CIAS 3.0** (Computerized Intervention Authoring System) is a HIPAA-regulated platform owned by **Michigan State University**. Researchers use it to build multi-session behavioral-health interventions without code, and participants then complete them. Features include branching, an animated narrator with TTS, SMS, PDF reports, charts, TLFB, live chat, and EHR integrations.

| Repo | Stack | GitHub |
|---|---|---|
| `cias-api` | Rails 7.2 · Ruby 3.3.8 · Postgres · Redis · Sidekiq · JSON:API | `github.com/Michigan-State-University/cias-api` |
| `cias-web` | React 17 · TypeScript · Redux + Redux-Saga · styled-components | `github.com/Michigan-State-University/cias-web` |

The code is open source (GPL-3). Both repos are public, so **never commit secrets or PHI**.

---

## 2. Environments

| Env | Web | API | Hosting | Git branch |
|---|---|---|---|---|
| Local | `http://localhost:4200` | `http://localhost:3000` | your machine | feature branch |
| **Test / staging** (legacy) | `https://test.cias.app` | `https://api-test.cias.app` | Dokku on EC2 (2 boxes) | `test` |
| **Test / staging** (new, ECS) | `https://test-ecs.cias.app` | `https://api-test-ecs.cias.app` | AWS ECS, cluster `cias-test` | ⚠️ TODO: confirm trigger branch |
| **Production** (MSU) | `https://msu.cias.app` | `https://api-msu.cias.app` | Dokku on EC2 (2 boxes) | `master` |

- `dev` is the integration branch and isn't deployed anywhere on its own. ⚠️ TODO: confirm.
- The two test stacks run **in parallel** while the ECS migration is in progress, and they have separate databases. Check which one QA is using before you debug "missing" data.
- There's no production on ECS yet. New client instances will go straight to ECS.
- Marketing site: `https://www.cias.app`.

### Servers (Dokku)

| Box | Apps | Git remote name |
|---|---|---|
| Test 1 | `cias-api`, `cias-web` | `cias-test-dokku1` |
| Test 2 | `cias-api`, `cias-web` | `cias-test-dokku2` |
| Prod 1 | `cias-web` (⚠️ TODO: confirm `cias-api` is on the same box) | `cias-prod-dokku1` |
| Prod 2 | `cias-web` (⚠️ TODO: confirm `cias-api` is on the same box) | `cias-prod-dokku2` |

The box IPs are in the vault (this file is in a public repo). Every environment has 2 boxes for redundancy, so **deploy to both**. SSH only works after your public key has been added on the box (`dokku ssh-keys:add`). Ask **TODO: who** to add it.

### AWS (ECS stack)

- Region **`us-east-2`**; the account ID is in the vault.
- ECR repos: `<account-id>.dkr.ecr.us-east-2.amazonaws.com/cias-api` and `/cias-web`.
- ECS cluster `cias-test` runs services `cias-test-api` and `cias-test-web`. Each task has an nginx sidecar that terminates TLS on 443.
- Logs are in CloudWatch log group **`ecs-cias-test`**. The `nginx` stream has the request lines. The `api` stream is nearly silent (see Gotchas).
- **MFA is enforced** by an explicit-deny policy, so plain access keys fail on almost every call. Get an MFA session first:
  ```bash
  aws sts get-session-token --profile cias \
    --serial-number arn:aws:iam::<account-id>:mfa/<your-device> --token-code <6 digits>
  # export the returned AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
  ```
- The raw `*.elb.amazonaws.com` hostname **always returns 404** because routing is by host header. Use the `*-ecs.cias.app` hostnames.

---

## 3. Access checklist (first day)

| Access to | Needed for |
|---|---|
| GitHub: `cias-api`, `cias-web` (MSU org) | code, PRs |
| Jira project (keys `CIAS30-…` / `CIAS-…`) | tickets |
| Confluence space | docs |
| Slack: TODO `#channel`, TODO `#channel` | team comms |
| Password manager vault | `.env` values, test accounts, Sidekiq basic auth |
| SSH key on Dokku boxes (test, later prod) | logs, console, deploys |
| AWS IAM user + MFA device | ECS / ECR / CloudWatch |
| Sentry | backend and frontend exceptions |
| LogRocket | frontend session replays |
| Google service-account JSON (from the vault) | local TTS / translation |
| Claude Code + the HTD Interlay connector on claude.ai | knowledge pills for the Claude workflows (see `cias-api/.claude-setup/README.md`) |
| Accounts on `test.cias.app` (admin, researcher) | manual testing |
| HIPAA training | required before touching prod data |

---

## 4. Local setup

### Backend: `cias-api`

```bash
# Ruby 3.3.8 (rvm or rbenv), PostgreSQL, Redis
git clone git@github.com:Michigan-State-University/cias-api.git && cd cias-api
cp .env.template .env            # fill in values from the vault
# put the Google service-account JSON file from the vault in the repo root
bundle install
rails db:migrate:reset
rails db:seed                     # role-based users, see below. NEVER on prod.
redis-server                      # own terminal; Sidekiq and ActionCable need it
rails s                           # :3000
bundle exec sidekiq -C config/sidekiq.yml   # another terminal; jobs (SMS, reports, TTS) need it
```
(Or keep Redis running in the background with `brew services start redis` and skip its terminal.)

You can use `docker compose up` instead. It starts the API, Postgres 13, Redis 6 and a Sidekiq worker.

**Seeded local users:** `<role>@<DOMAIN_NAME>` with password `Password123!`. `DOMAIN_NAME` defaults to `example.com`, which gives you e.g. `researcher@example.com`, `admin@example.com` and `participant@example.com`.
The seeded roles are `admin`, `researcher`, `participant`, `guest`, `navigator`, `health_system_admin`, `health_clinic_admin` and `predefined_participant`.

**Local helpers**

| URL | What |
|---|---|
| `localhost:3000/rails/browse_emails` | emails sent locally (letter_opener). Grab 2FA codes here. |
| `localhost:3000/rails/workers` | Sidekiq UI (needs `SIDEKIQ_WEB_INTERFACE=1` + basic auth) |
| `localhost:3000/rails/info/routes` | all routes |

**macOS:** if audio generation crashes with `objc[...] +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called`, add `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` to `~/.zshrc`.

### Frontend: `cias-web`

```bash
# Node 22.x (.nvmrc, package.json engines and CI all agree)
nvm install && nvm use
git clone https://github.com/Michigan-State-University/cias-web.git && cd cias-web
cp .env.example .env
#   API_URL=http://localhost:3000
#   WEBSOCKET_URL=ws://localhost:3000/cable
#   WEB_URL=http://localhost:4200
npm install
npm start                         # :4200
```

---

## 5. Everyday commands

| | Backend (`cias-api`) | Frontend (`cias-web`) |
|---|---|---|
| Tests | `bundle exec rspec` | `npm test` |
| Lint | `bundle exec rubocop` | `npm run lint` · `npm run lint:css` |
| Types | — | `npx tsc --noEmit` (**the prod build does NOT type-check**) |
| Security audit | `bundle exec bundler-audit` | `npm audit` |
| E2E | — | `npm run e2e` (Playwright) · `npm run e2e:ui` |
| Console | `rails c` | — |

CI runs on GitHub Actions. On every push, the API runs RuboCop, bundler-audit and RSpec split into parallel chunks. A red RuboCop fails the build.

---

## 6. Git flow and releases

```
feature branch  →  dev  →  test  →  master (prod)
```

- **Branch from `dev`** and name branches after the ticket, e.g. `CIAS30-4117-improve-import-modal`. Open the PR into `dev`.
- **Never commit directly** to `dev`, `test` or `master`. Everything goes through a PR.
- **Promotion** goes through dated branches, not direct merges:
  - `dev → test`: branch `dev_to_test_<DDMMYYYY>`, PR into `test`
  - `test → master`: branch `test_to_master_<DDMMYYYY>`, PR into `master`
- **List releases:** `git log --oneline --first-parent origin/master`
- **Hotfix:** branch off `master`, merge to `master`, then `git cherry-pick` **the same commit** into `dev`. Don't re-author the fix by hand.
- **Gotcha:** a promotion PR's "Files changed" tab can show files that `master` already has, e.g. an earlier hotfix. GitHub diffs from the merge base. Those files merge with no net change.

### Deploying (Dokku)

⚠️ **TODO: confirm who deploys and when.** Ask before your first deploy, and never deploy to prod on your own.

```bash
git remote add cias-test-dokku1 dokku@<test-box-1-ip>:cias-api   # IPs from the vault (and :cias-web in that repo)
git remote add cias-test-dokku2 dokku@<test-box-2-ip>:cias-api
git push cias-test-dokku1 test:master                           # then the same for dokku2
```

The API's Procfile has `release: rails db:migrate`, so **migrations run automatically on deploy**.

### Useful Dokku commands

```bash
ssh dokku@<ip> apps:list
ssh dokku@<ip> ps:report cias-api
ssh dokku@<ip> logs cias-api -t               # tail web logs
ssh dokku@<ip> logs cias-api -p worker -t     # tail Sidekiq
ssh -t dokku@<ip> run cias-api rails c        # one-off console. On PROD this means PHI, so be careful.
ssh dokku@<ip> config:show cias-api           # prints SECRETS. Don't paste the output anywhere.
```

---

## 7. Debugging: where to look

| Tool | Shows | Notes |
|---|---|---|
| **Sentry** | backend and frontend exceptions | Some exceptions are **deliberately not sent**; see `cias-api/app/controllers/concerns/exception_handler.rb`. The project is named `cias-api-staging`, but production events land there too. ⚠️ TODO: confirm the project list. |
| **LogRocket** | frontend session replay, network calls, console | `cias-web` only. Sensitive fields are sanitized. |
| **Rails logs** | requests | Prod `log_level` is hardcoded to `:warn`, so request logs are nearly empty. Don't expect much. |
| **Sidekiq UI** | jobs, retries, dead set | `<api-host>/rails/workers` (basic auth) |

- Local dev has **no** Sentry or LogRocket, because their env vars aren't set.
- A failed saga in `cias-web` usually shows up only as a failed request plus a toast. It doesn't reach Sentry.
- `test.cias.app` asks for an **emailed 2FA code** on any new browser. Tick "Remember this browser for 30 days". The first `sign_in` returning **403** is expected, not a bug.

---

## 8. Domain in one screen

```
Organization → HealthSystem → HealthClinic          (org hierarchy, invitations)
Intervention → Session → QuestionGroup → Question   (content, Rails STI)
User ─ UserIntervention ─ UserSession ─ Answer      (participant runtime)
```

| Term | Meaning |
|---|---|
| Intervention / Session | a program, and one sitting of that program |
| Branching / Formula | Dentaku formulas on answer variables that decide the next question or session |
| Narrator ("Peedy") | animated character + Google TTS that reads questions aloud |
| Report template | PDF generated when a session finishes (WickedPdf), sent by email or fax |
| SMS plan | post-session SMS messages via Twilio |
| TLFB | Timeline Follow-Back: a calendar-based substance-use assessment |
| CAT-MH | external adaptive mental-health assessment |
| HFHS / Epic on FHIR | Henry Ford Health EHR integration (HL7 v2.5 + FHIR) |
| Navigator | live-chat helper for participants (ActionCable) |
| e-intervention admin, team admin, researcher… | roles, see `User::APP_ROLES` |

---

## 9. Gotchas worth knowing on day one

- **PHI/HIPAA.** Never paste participant data into Slack, Jira, PR descriptions, Sentry comments or AI tools. PHI columns are encrypted with Lockbox, and changes are tracked with Audited or PaperTrail. Read the security rules before you add a field that holds personal data.
- **Auth tokens rotate on every request.** The headers are `access-token`, `uid` and `client`, and a token lives about 15 minutes. If you replay an old request in Postman, expect a 401.
- **`cias-web` bakes `API_URL`, `WEBSOCKET_URL` and `WEB_URL` into the JS bundle at build time.** Changing a hostname means a rebuild and redeploy. Changing runtime env does nothing.
- **API CORS** allows only `WEB_URL` + `ADDITIONAL_CORS_ORIGINS`. Pointing a new frontend host at an API makes requests fail until you update these.
- **Sagas use hand-written URLs.** When you change an API endpoint, grep `cias-web/app/global/reducers/` and `app/containers/` for its consumers.
- The Twilio inbound controller really is named `TwilloMessageController`. That typo is in the code.
- **No ticket numbers in code** — not in filenames, classes, constants or spec `describe` strings. Name things after the behaviour; a `CIAS-NNNN` in a comment is fine.
- **Don't edit `.github/workflows/code-quality.yml`** (HTD code-quality / SonarQube scan) in either repo, even when bumping every workflow's actions.
- **Don't merge `@anycable/web` ≥ 0.4** (Dependabot keeps proposing it) until cias-api stops sending a duplicate `confirm_subscription` — AnyCable 1.x answers it with `unsubscribe`, which drops the intervention edit lock.
- **Dependency bumps:** read the release notes for every package and version in the range (`/bump-gems`, `/bump-npm-packages` do this). Semver + green tests is not enough.
- Rails 7.2 security support ended in August 2026. An upgrade to 8.1 is planned or in progress. ⚠️ TODO: link the ticket.

---

## 10. Suggested first week

1. Get both apps running locally and log in as `researcher@example.com`.
2. Build a small intervention: 2 sessions, a few question types, one branching rule, and narrator on.
3. Take it as a participant in another browser. Watch the answers, the Sidekiq jobs and the emails in `/rails/browse_emails`.
4. Add a report template and see the PDF generate when the session finishes.
5. Pick up a small `good first issue` ticket (TODO: Jira filter link).

## 11. Links

- Jira board: TODO
- Sentry: TODO · LogRocket: TODO
- AWS console (us-east-2): TODO
- Architecture and deep dives: knowledge pills in Interlay (project CIAS) · TODO: Confluence page
- Team contacts: tech lead TODO · DevOps TODO · PM TODO

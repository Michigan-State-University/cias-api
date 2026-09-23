#!/usr/bin/env bash
#
# Downloads ci.yml's collated "coverage-report" artifact for a commit into
# ./coverage, for the Code Quality workflow to hand to SonarQube.
#
# ci.yml and code-quality.yml start on the same event, so the artifact does not
# exist yet -- hence the bounded poll. Every failure path here exits 0 without a
# report: the scan then runs with --skip-coverage, because the security findings
# do not depend on coverage.
#
# Required env: GH_TOKEN, GITHUB_REPOSITORY, HEAD_SHA, COVERAGE_WAIT_MINUTES
#
# No `set -e`: a transient API error should fall through to the next poll rather
# than kill the step.

set -uo pipefail

deadline=$(( $(date +%s) + COVERAGE_WAIT_MINUTES * 60 ))
artifact_id=""
tick=0

while : ; do
  # Artifacts carry workflow_run.head_sha, so one filtered call answers this --
  # no run listing, no per-run artifact call. `last` takes the newest upload
  # when ci.yml has been re-run.
  artifact_id=$(gh api --paginate \
    "repos/${GITHUB_REPOSITORY}/actions/artifacts?name=coverage-report&per_page=100" \
    --jq "[.artifacts[]
           | select(.workflow_run.head_sha == \"${HEAD_SHA}\" and .expired == false)]
          | last | .id // empty" 2>/dev/null)
  [ -n "${artifact_id}" ] && break

  # Tell "not yet" apart from "never". ci.yml gates its spec matrix on Rubocop,
  # so a lint failure skips the shards and no artifact is ever uploaded --
  # without this the job sits out the whole deadline for a verdict already
  # known. Checked every 5th tick to stay cheap; a zero run count means ci.yml
  # has not started, which is "not yet", not "never".
  if [ $(( tick % 5 )) -eq 0 ]; then
    counts=$(gh api --paginate \
      "repos/${GITHUB_REPOSITORY}/actions/runs?head_sha=${HEAD_SHA}&per_page=100" \
      --jq '[.workflow_runs[] | select(.path == ".github/workflows/ci.yml")]
            | [length, ([.[] | select(.status != "completed")] | length)]
            | @tsv' 2>/dev/null)
    total=$(printf '%s' "${counts}" | cut -f1)
    running=$(printf '%s' "${counts}" | cut -f2)
    if [ "${total:-0}" -gt 0 ] && [ "${running:-1}" -eq 0 ]; then
      echo "::warning::ci.yml finished for ${HEAD_SHA} without a coverage-report; scanning without coverage."
      exit 0
    fi
  fi

  if [ "$(date +%s)" -ge "${deadline}" ]; then
    echo "::warning::No coverage-report artifact after ${COVERAGE_WAIT_MINUTES}m; scanning without coverage."
    exit 0
  fi
  tick=$(( tick + 1 ))
  sleep 30
done

mkdir -p coverage
gh api "repos/${GITHUB_REPOSITORY}/actions/artifacts/${artifact_id}/zip" \
  > /tmp/coverage-report.zip
unzip -oq /tmp/coverage-report.zip -d coverage
rm -f /tmp/coverage-report.zip

# Paths are already repo-relative: SonarJSONFormatter strips the SimpleCov root
# during collation. Verified here because an absolute path imports as 0% with
# only a WARN, which is easy to miss.
if [ ! -s coverage/coverage.json ]; then
  echo "::warning::coverage-report artifact contained no coverage.json; scanning without coverage."
  rm -rf coverage
elif jq -e '.coverage | keys | any(startswith("/"))' coverage/coverage.json >/dev/null 2>&1; then
  echo "::warning::coverage.json holds absolute paths and would import as 0%; scanning without coverage."
  rm -rf coverage
fi

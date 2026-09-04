# frozen_string_literal: true

# The only supported entry point to `V1::Charts::Regenerate`.
#
# The service itself has no production caller: `RegenerateChartsJob` is enqueued only by
# `V1::ChartStatistics::RegenerateForOrganizations`, which nothing in `app/`, `lib/` or `config/`
# calls, so regeneration has until now been reachable only from a Rails console. This wraps it
# with the guards a console session does not give you.
#
# DESTRUCTIVE: with `replace: true` (the default) `V1::Charts::Regenerate` runs
# `ChartStatistic.where(chart_id: chart_ids).destroy_all` BEFORE replaying. The replay rebuilds
# rows from `CreateForUserSessions`, which re-finds participants by matching `session.variable`
# against the chart formula's variable prefixes — so any row whose originating session no longer
# qualifies (renamed session variable, edited formula, deleted session) is destroyed and NOT
# recreated. Hence the explicit confirmation.
namespace :chart_statistics do
  desc 'Regenerate chart statistics for chart IDs (CHART_IDS=uuid,uuid REPLACE=true CONFIRM=yes)'
  task regenerate: :environment do
    # Postgres accepts mixed-case uuids and passes them through unchanged, so an uppercase id
    # would match `found` while still appearing in `missing` - normalise before comparing.
    chart_ids = ENV.fetch('CHART_IDS', '').downcase.split(',').map(&:strip).reject(&:empty?)

    # REPLACE picks between a DESTRUCTIVE and a non-destructive path, so both sides are explicit
    # allow-lists and anything else aborts. A denylist would read `REPLACE=n` (or `f`, or a typo,
    # or an empty value) as "yes, destroy" - the silent inversion this guards. Unset still defaults
    # to destructive, which is the documented behaviour.
    replace_true = %w[true t yes y 1 on]
    replace_false = %w[false f no n 0 off]
    replace_raw = ENV.fetch('REPLACE', 'true').to_s.strip.downcase

    unless replace_true.include?(replace_raw) || replace_false.include?(replace_raw)
      abort "REPLACE=#{replace_raw.inspect} is not recognised; use one of " \
            "#{(replace_true + replace_false).join(', ')}"
    end

    replace = replace_true.include?(replace_raw)

    abort 'CHART_IDS is required, e.g. CHART_IDS=uuid1,uuid2' if chart_ids.empty?

    # Mirrors the only other entry point (`regenerate_for_organizations.rb:25`): a draft chart has
    # never collected, and replaying one would retroactively materialise statistics for it.
    found = Chart.where(id: chart_ids, status: %w[data_collection published])
    missing = chart_ids - found.map(&:id)
    abort "Unknown, or draft, chart id(s): #{missing.join(', ')}" if missing.any?

    if replace
      row_count = ChartStatistic.where(chart_id: chart_ids).count
      puts "REPLACE mode: #{row_count} existing ChartStatistic row(s) across #{found.size} chart(s) " \
           'will be DESTROYED and replayed.'
      puts 'Rows whose originating session no longer matches the formula will NOT be recreated.'
    else
      # The "safe" path is not read-only: the replay still upserts, and on a legacy `min == 0`
      # chart the de-dup key includes `label`, so a participant can gain a second row
      # (`create.rb:236-242`). Both paths therefore need the confirmation.
      puts "REPLAY mode: no rows are destroyed, but #{found.size} chart(s) will be replayed and " \
           'rows may be added.'
    end

    abort 'Refusing to run without CONFIRM=yes' unless ENV['CONFIRM'] == 'yes'

    V1::Charts::Regenerate.call(chart_ids, replace: replace)
    puts "Regenerated #{found.size} chart(s); now #{ChartStatistic.where(chart_id: chart_ids).count} row(s)."
  end
end

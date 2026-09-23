# frozen_string_literal: true

namespace :test_participants do
  desc 'Re-enqueue test-participant purges that fell due and never ran (e.g. a lost Redis scheduled set). ' \
       'DRY_RUN=1 previews; MAX_PURGES=<n> raises the per-run ceiling.'
  task reconcile_stranded_purges: :environment do
    service = V1::Intervention::TestParticipants::ReconcileStrandedPurges

    # A present-but-empty `DRY_RUN` is what `DRY_RUN=$UNSET_VAR` leaves behind — the operator asked
    # for a preview and the shell ate the value — so it previews. Only an explicit falsey spelling
    # (`0`, `false`, `off`, `f`, `FALSE`) or omitting the variable entirely runs for real.
    dry_run = ENV.key?('DRY_RUN') && ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil)) != false
    max_purges = ENV.fetch('MAX_PURGES', nil).presence&.to_i || service::MAX_PURGES_PER_RUN

    result = service.call(dry_run: dry_run, max_purges: max_purges)
    ids = result.candidate_ids

    puts "Stranded test-participant purges found: #{result.found}"
    puts "Candidate user ids (#{ids.first(50).size} of #{ids.size}): #{ids.first(50).join(', ')}" if ids.any?

    if result.refused?
      puts "REFUSED — #{result.found} candidates is over the #{result.max_purges}-purge ceiling for one run."
      puts 'Nothing was enqueued. Review the ids above, then re-run with MAX_PURGES=<n> if they are expected.'
    elsif result.dry_run?
      puts 'Dry run — nothing was enqueued. Re-run without DRY_RUN to recover them.'
    else
      puts "Purges re-enqueued on the `test_participant_purge` queue: #{result.enqueued}"
    end

    puts 'Note: a purge is irreversible and has no grace window.'
  end
end

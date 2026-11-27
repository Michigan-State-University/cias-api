# frozen_string_literal: true

namespace :predefined_participants do
  desc 'Re-enqueue SMS campaigns that fell due and never finished (e.g. a lost Redis scheduled set). ' \
       'DRY_RUN=1 previews; MAX_CAMPAIGNS=<n> raises the per-run ceiling.'
  task reconcile_campaigns: :environment do
    service = V1::PredefinedParticipants::SmsCampaigns::ReconcileStrandedCampaigns

    dry_run = ENV.key?('DRY_RUN') && ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil)) != false
    max_campaigns = ENV.fetch('MAX_CAMPAIGNS', nil).presence&.to_i || service::MAX_CAMPAIGNS_PER_RUN

    result = service.call(dry_run: dry_run, max_campaigns: max_campaigns)
    ids = result.candidate_ids

    puts "Stranded SMS campaigns found: #{result.found}"
    puts "Candidate campaign ids (#{ids.first(50).size} of #{ids.size}): #{ids.first(50).join(', ')}" if ids.any?

    if result.refused?
      puts "REFUSED - #{result.found} candidates is over the #{result.max_campaigns}-campaign ceiling for one run."
      puts 'Nothing was enqueued. Review the ids above, then re-run with MAX_CAMPAIGNS=<n> if they are expected.'
    elsif result.dry_run?
      puts 'Dry run - nothing was enqueued. Re-run without DRY_RUN to recover them.'
    else
      puts "Campaign jobs re-enqueued on the `sms_plans` queue: #{result.enqueued}"
    end
  end
end

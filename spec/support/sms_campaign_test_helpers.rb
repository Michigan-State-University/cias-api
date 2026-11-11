# frozen_string_literal: true

require 'active_support/testing/time_helpers'

module SmsCampaignTestHelpers # rubocop:disable Metrics/ModuleLength
  CANARY_BODY = 'CIAS_TDD_CANARY_BODY'
  HIGH_LIMIT = 1_000

  SETTING_KEYS = {
    throttle_ip: :throttle_ip_per_minute,
    throttle_user: :throttle_user_per_hour,
    throttle_intervention: :throttle_intervention_per_hour,
    daily_cap: :daily_sms_cap
  }.freeze

  CAMPAIGN_JOB = '::PredefinedParticipants::SendSmsCampaignJob'

  def campaign_job_class
    CAMPAIGN_JOB.constantize
  end

  def with_sms_campaign_settings(overrides)
    section = Settings.sms_campaigns
    saved = overrides.keys.index_with { |key| section.key?(key) ? [true, section[key]] : [false, nil] }
    begin
      overrides.each { |key, value| section[key] = value }
      yield
    ensure
      saved.each do |key, (had, old)|
        had ? section[key] = old : section.delete_field(key)
      end
    end
  end

  def campaign_setting_key(name)
    SETTING_KEYS.fetch(name)
  end

  def with_real_rack_attack_store
    cache = Rack::Attack.cache.store
    enabled = Rack::Attack.enabled
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    yield
  ensure
    Rack::Attack.enabled = enabled
    Rack::Attack.cache.store = cache
  end

  def campaign_researcher
    create(:user, :researcher, :confirmed)
  end

  PHONE_POOL = %w[2015550123 2015550124 2015550125 2015550126 2015550127 2015550128 2015550129 2015550130].freeze

  def campaign_participant(intervention, index: 0, phone: true)
    user = create(:user, :predefined_participant, :confirmed)
    user.predefined_user_parameter.update!(intervention_id: intervention.id)
    Phone.create!(user: user, iso: 'US', prefix: '+1', number: PHONE_POOL.fetch(index)) if phone
    user.predefined_user_parameter
  end

  # Redis is shared between test processes: never `clear`, delete only the ids pushed here.
  # `queue_adapter=` on the class would create its own class_attribute and permanently break inheritance.
  def with_real_sidekiq_for_campaign_job
    job_class = campaign_job_class
    adapter = ActiveJob::QueueAdapters::SidekiqAdapter.new
    job_class.define_singleton_method(:queue_adapter) { adapter }
    @pushed_campaign_ids = []
    yield
  ensure
    job_class.singleton_class.send(:remove_method, :queue_adapter) if job_class&.singleton_class&.method_defined?(:queue_adapter, false)
    delete_scheduled_entries_for(@pushed_campaign_ids || [])
  end

  def enqueue_campaign_job_in_sidekiq(campaign, *extra_arguments, at: 3.days.from_now)
    @pushed_campaign_ids << campaign.id
    campaign_job_class.set(wait_until: at).perform_later(campaign.id, *extra_arguments)
  end

  # Same job class, but the campaign id sits at argument position 5 instead of 0 (the `SmsPlans::SendSmsJob` signature).
  def push_decoy_job_with_campaign_id_at_position5(campaign, decoy_owner_id: SecureRandom.uuid, at: 3.days.from_now)
    @pushed_campaign_ids << decoy_owner_id
    @pushed_campaign_ids << campaign.id
    payload = campaign_job_class.new(decoy_owner_id).serialize
    payload['arguments'] = [decoy_owner_id, nil, nil, nil, nil, campaign.id]
    Sidekiq::Client.push(
      'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
      'wrapped' => campaign_job_class.name,
      'queue' => 'sms_plans',
      'args' => [payload],
      'at' => at.to_f
    )
  end

  def push_foreign_class_job(campaign, at: 3.days.from_now)
    @pushed_campaign_ids << campaign.id
    Sidekiq::Client.push(
      'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
      'wrapped' => 'SmsPlans::SendSmsJob',
      'queue' => 'sms_plans',
      'args' => [{ 'job_class' => 'SmsPlans::SendSmsJob', 'job_id' => SecureRandom.uuid, 'queue_name' => 'sms_plans',
                   'arguments' => [campaign.id], 'locale' => 'en' }],
      'at' => at.to_f
    )
  end

  def scheduled_entries_with_arguments(ids)
    wanted = Array(ids)
    Sidekiq::ScheduledSet.new.select do |entry|
      payload = entry.args.first
      payload.is_a?(Hash) && Array(payload['arguments']).intersect?(wanted)
    end
  end

  def scheduled_entry_present?(job_class_name:, first_argument:)
    Sidekiq::ScheduledSet.new.any? do |entry|
      payload = entry.args.first
      payload.is_a?(Hash) && payload['job_class'] == job_class_name && Array(payload['arguments']).first == first_argument
    end
  end

  def campaign_job_scheduled?(campaign_id)
    scheduled_entry_present?(job_class_name: campaign_job_class.name, first_argument: campaign_id)
  end

  def delete_scheduled_entries_for(ids)
    scheduled_entries_with_arguments(ids).each(&:delete)
  end

  # A refusal may be raised or returned; NameError is re-raised so a missing constant or method fails the example.
  def attempt_capturing_error
    yield
  rescue NameError
    raise
  rescue StandardError => e
    e
  end

  def recorded_queries(pattern = nil)
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
      next if payload[:cached]
      next if %w[SCHEMA TRANSACTION].include?(payload[:name])

      queries << payload[:sql]
    end
    yield
    pattern ? queries.grep(pattern) : queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def cancel_service_class
    V1::PredefinedParticipants::SmsCampaigns::CancelService
  end

  def sms_campaigns_api_path(intervention_id, suffix = nil)
    base = "/v1/interventions/#{intervention_id}/predefined_participants/sms_campaigns"
    suffix ? "#{base}/#{suffix}" : base
  end
end

module SmsCampaignJobHelpers
  CAMPAIGN_JOB = 'PredefinedParticipants::SendSmsCampaignJob'
  CANARY_BODY = 'CIAS_TDD_CANARY_BODY'

  def create_us_phone!(user, index = 0)
    create(:phone, user: user, iso: 'US', prefix: '+1', number: (2_015_550_123 + index).to_s)
  end

  def pushed_jids
    @pushed_jids ||= []
  end

  # Pushes a real entry into Sidekiq::ScheduledSet the way ActiveJob does in production (the global test adapter never reaches Redis).
  def push_campaign_job(*, at: 2.days.from_now)
    job = PredefinedParticipants::SendSmsCampaignJob.new(*)
    ActiveJob::QueueAdapters::SidekiqAdapter.new.enqueue_at(job, at.to_f)
    pushed_jids << job.provider_job_id
    job.provider_job_id
  end

  def jid_scheduled?(jid)
    Sidekiq::ScheduledSet.new.find_job(jid).present?
  end

  def delete_pushed_jobs
    set = Sidekiq::ScheduledSet.new
    pushed_jids.each { |jid| set.find_job(jid)&.delete }
  end

  def silence_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  def build_campaign_params(attrs = {})
    ActionController::Parameters.new({ kind: 'invitation', body: CANARY_BODY }.merge(attrs)).permit!
  end

  def stub_successful_sms_delivery
    allow_any_instance_of(Communication::Sms).to receive(:send_message) do |sms|
      sms.sms.update(status: 'success')
      true
    end
  end

  # Runs cancel and reports whether the service refused (raised ComplexException or returned falsey).
  def cancel_refused?(service, campaign)
    result = service.call(campaign)
    !result
  rescue ComplexException
    true
  end
end

RSpec.configure do |config|
  config.include SmsCampaignTestHelpers
  config.include SmsCampaignJobHelpers
  config.include ActiveSupport::Testing::TimeHelpers
end

# Rack::Attack keeps its own store: Rails.cache is :null_store in test (config/environments/test.rb),
# so without swapping Rack::Attack.cache.store the throttle would never count a single request.
RSpec.shared_context 'with real rack attack store' do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    cache    = Rack::Attack.cache.store
    enabled  = Rack::Attack.enabled
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    example.run
  ensure
    Rack::Attack.enabled = enabled
    Rack::Attack.cache.store = cache
  end

  # Pinned inside a minute and an hour bucket so no window can roll over mid-example.
  before { travel_to Time.utc(2026, 11, 2, 12, 10, 5) }
end

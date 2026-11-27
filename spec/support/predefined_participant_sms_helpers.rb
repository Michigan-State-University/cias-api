# frozen_string_literal: true

require 'active_support/testing/time_helpers'
require 'support/phone_number_fixtures'

module QueryRecordingHelpers
  def count_queries(&block) = collect_queries(&block).size

  def collect_queries
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
      next if payload[:cached]
      next if %w[SCHEMA TRANSACTION].include?(payload[:name])

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def record_enqueues
    events = []
    subs = %w[enqueue.active_job enqueue_at.active_job].map do |name|
      ActiveSupport::Notifications.subscribe(name) do |*, payload|
        events << { class_name: payload[:job].class.name, arguments: payload[:job].arguments,
                    depth: ActiveRecord::Base.lease_connection.open_transactions }
      end
    end
    yield
    events
  ensure
    subs&.each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
  end

  def transaction_depth
    ActiveRecord::Base.lease_connection.open_transactions
  end
end

module PredefinedParticipantSmsHelpers
  include ActiveSupport::Testing::TimeHelpers
  include QueryRecordingHelpers

  def canary_body = 'CIAS_TDD_CANARY_BODY'
  def canary_variable = 'canary_link'
  def canary_url = 'https://example.test/canary-target'
  def canary_slug = 'ciastddcanaryslug'
  def frozen_now = NOW

  def web_url
    ENV.fetch('WEB_URL', nil).to_s
  end

  def personal_link_expected_length
    "#{web_url}/usr/".length + 8
  end

  def tracked_link_expected_length
    "#{web_url}/link/".length + 9
  end

  def us_phone(index)
    { iso: 'US', prefix: '+1', number: format('20155501%<n>02d', n: 23 + index) }
  end

  def make_participant(intervention, index: 0, phone: :default, **options)
    active = options.fetch(:active, true)
    confirmed = options.fetch(:confirmed, false)
    invited_at = options[:invited_at]
    pup_attrs = options.except(:active, :confirmed, :invited_at)
    user = create(:user, :predefined_participant, :confirmed)
    user.predefined_user_parameter.update!(intervention: intervention, sms_invitation_sent_at: invited_at, **pup_attrs)
    create(:phone, user: user, confirmed: confirmed, **(phone == :default ? us_phone(index) : phone)) unless phone.nil?
    user.update!(active: false) unless active
    user.predefined_user_parameter.reload
  end

  def capture_complex_exception
    yield
    nil
  rescue ComplexException => e
    e
  end

  def http_status(exception)
    Rack::Utils.status_code(exception.status_code || :unprocessable_content)
  end

  def error_codes(exception)
    info = exception.additional_information.to_h.with_indifferent_access
    codes = Array(info[:errors]).map { |entry| entry.to_h.with_indifferent_access[:code].to_s }
    (codes + [info[:reason].to_s]).compact_blank
  end

  def deep_values(object)
    case object
    when Hash then object.values.flat_map { |value| deep_values(value) }
    when Array then object.flat_map { |value| deep_values(value) }
    else [object]
    end
  end

  class FailingQueueAdapter < ActiveJob::QueueAdapters::AbstractAdapter
    attr_reader :attempts

    def initialize
      super
      @attempts = 0
    end

    def enqueue(_job)
      @attempts += 1
      raise RedisClient::CannotConnectError, 'redis unavailable'
    end

    def enqueue_at(_job, _timestamp)
      @attempts += 1
      raise RedisClient::CannotConnectError, 'redis unavailable'
    end
  end

  WEB_URL = 'https://web.example.test'
  TRACKED_URL = 'https://example.test/canary-target'
  CANARY_BODY = 'CIAS_TDD_CANARY_BODY'
  UNPROCESSABLE = [:unprocessable_content, :unprocessable_entity, 422].freeze
  CONFLICT = [:conflict, 409].freeze
  BAD_REQUEST = [:bad_request, 400].freeze
  LEAKY_SQL = /PG::|duplicate key|index_pp|INSERT INTO|violates|unique constraint|constraint/i
  NOW = Time.zone.parse('2026-10-30 12:00:00')

  def stub_web_url
    stub_const('ENV', ENV.to_hash.merge('WEB_URL' => WEB_URL))
  end

  def create_participant(intervention, active: true, phone: :default, confirmed: false, **pup_attrs)
    user = create(:user, roles: %w[predefined_participant], active: active)
    pup = create(:predefined_user_parameter, intervention: intervention, user: user, **pup_attrs)
    unless phone.nil?
      phone_attrs = phone == :default ? {} : phone
      create(:phone, user: user, confirmed: confirmed, **phone_attrs)
    end
    pup
  end

  def link_params(variable: 'canary_link', url: TRACKED_URL, link_type: 'website')
    { url: url, variable: variable, link_type: link_type }
  end

  def info_of(exception)
    (exception.additional_information || {}).with_indifferent_access
  end

  def codes_of(exception)
    info = info_of(exception)
    Array(info[:errors]).map { |error| error.with_indifferent_access[:code].to_s } + [info[:reason]].compact.map(&:to_s)
  end
end

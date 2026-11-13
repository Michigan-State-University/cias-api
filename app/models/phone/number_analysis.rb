# frozen_string_literal: true

class Phone::NumberAnalysis
  SMS_TYPES = %i[mobile fixed_or_mobile].freeze
  EXCLUDED_TYPES = %i[premium_rate].freeze

  def initialize(prefix, number)
    @prefix = prefix.to_s
    @number = number.to_s
    @parsed = Phonelib.parse(@prefix + @number) if @prefix.present? && @number.present?
  end

  def analysable?
    !@parsed.nil?
  end

  def valid?
    analysable? && @parsed.valid?
  end

  def parts(with_iso:)
    base = { prefix: @parsed.e164.delete_suffix(@parsed.raw_national), number: @parsed.raw_national }
    with_iso ? base.merge(iso: @parsed.country) : base
  end

  def e164
    @parsed.e164 if valid?
  end

  def sms_eligible?
    valid? && sms_type?
  end

  private

  def sms_type?
    @parsed.types.intersect?(SMS_TYPES) && !@parsed.types.intersect?(EXCLUDED_TYPES)
  end
end

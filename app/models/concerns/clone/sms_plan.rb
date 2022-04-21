# frozen_string_literal: true

class Clone::SmsPlan < Clone::Base
  def execute
    outcome.name = "Copy of #{source.name}"
    ActiveRecord::Base.transaction do
      outcome.save!
      create_sms_variants
      create_alert_phones
    end
    outcome
  end

  private

  def create_sms_variants
    source.variants.each do |variant|
      outcome.variants << SmsPlan::Variant.new(variant.slice(SmsPlan::Variant::ATTR_NAMES_TO_COPY))
    end
  end

  def create_alert_phones
    return unless source.alert?

    source.alert_phones.each do |alert_phone|
      outcome.alert_phones << AlertPhone.new(sms_plan: outcome, phone: alert_phone.phone)
    end
  end
end

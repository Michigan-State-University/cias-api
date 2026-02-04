# frozen_string_literal: true

class Clone::SmsPlan < Clone::Base
  def execute
    outcome.name = "Copy of #{source.name}"
    ActiveRecord::Base.transaction do
      outcome.save!
      create_sms_variants
      create_alert_phones
      create_sms_links
    end
    attach_no_formula_attachment
    outcome
  end

  private

  def create_sms_variants
    source.variants.find_each do |variant|
      newly_created_variant = SmsPlan::Variant.create(variant.slice(SmsPlan::Variant::ATTR_NAMES_TO_COPY).merge(sms_plan_id: outcome.id))
      newly_created_variant.attachment.attach(variant.attachment.blob) if variant.attachment.attached?
    end
  end

  def attach_no_formula_attachment
    return unless source.no_formula_attachment.attached?

    outcome.no_formula_attachment.attach(source.no_formula_attachment.blob)
  end

  def create_alert_phones
    return unless source.alert?

    source.alert_phones.find_each do |alert_phone|
      outcome.alert_phones << AlertPhone.new(sms_plan: outcome, phone: alert_phone.phone)
    end
  end

  def create_sms_links
    source.sms_links.find_each do |sms_link|
      outcome.sms_links << SmsLink.new(sms_plan: outcome, url: sms_link.url, link_type: sms_link.link_type, variable: sms_link.variable)
    end
  end
end

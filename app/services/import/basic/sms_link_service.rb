# frozen_string_literal: true

class Import::Basic::SmsLinkService
  attr_reader :sms_plan_id, :sms_link_hash, :variant_id

  def self.call(sms_plan_id, sms_link_hash, variant_id: nil)
    new(sms_plan_id, sms_link_hash, variant_id: variant_id).call
  end

  def initialize(sms_plan_id, sms_link_hash, variant_id: nil)
    @sms_plan_id = sms_plan_id
    @sms_link_hash = sms_link_hash
    @variant_id = variant_id
  end

  def call
    SmsLink.create!(
      sms_plan_id: sms_plan_id,
      variant_id: variant_id,
      url: sms_link_hash[:url],
      link_type: sms_link_hash[:link_type],
      variable: sms_link_hash[:variable]
    )
  end
end

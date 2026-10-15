# frozen_string_literal: true

class Import::Basic::SmsPlanService
  include ImportOperations

  attr_reader :session_id, :sms_plan_hash

  def self.call(session_id, sms_plan_hash)
    new(session_id, sms_plan_hash.except(:version)).call
  end

  def initialize(session_id, sms_plan_hash)
    @sms_plan_hash = sms_plan_hash
    @session_id = session_id
  end

  def call
    variants = sms_plan_hash.delete(:variants)
    sms_links = sms_plan_hash.delete(:sms_links)
    sms_plan = SmsPlan.create!(sms_plan_hash.merge({ session_id: session_id }))
    variants&.each do |variant_hash|
      get_import_service_class(variant_hash, SmsPlan::Variant).call(sms_plan.id, variant_hash)
    end
    sms_links&.each do |sms_link_hash|
      Import::Basic::SmsLinkService.call(sms_plan.id, sms_link_hash)
    end
    sms_plan
  end
end

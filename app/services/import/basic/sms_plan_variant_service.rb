# frozen_string_literal: true

class Import::Basic::SmsPlanVariantService
  include ImportOperations

  attr_reader :sms_plan_variant_hash, :sms_plan_id, :position

  def self.call(sms_plan_id, sms_plan_variant_hash)
    new(sms_plan_id, sms_plan_variant_hash.except(:version)).call
  end

  def initialize(sms_plan_id, sms_plan_variant_hash)
    @sms_plan_variant_hash = sms_plan_variant_hash
    @sms_plan_id = sms_plan_id
    @position = sms_plan_variant_hash[:position] || 0
  end

  def call
    variant = SmsPlan::Variant.create!(sms_plan_variant_hash.merge(sms_plan_id: sms_plan_id))
    variant.update!(position: position)
    variant
  end
end

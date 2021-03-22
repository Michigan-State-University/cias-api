# frozen_string_literal: true

class Clone::SmsPlan < Clone::Base
  def execute
    outcome.name = "Copy of #{source.name}"
    outcome.save!
    create_sms_variants
    outcome
  end

  private

  def create_sms_variants
    source.variants.each do |variant|
      outcome.variants << SmsPlan::Variant.new(variant.slice(SmsPlan::Variant::ATTR_NAMES_TO_COPY))
    end
  end
end

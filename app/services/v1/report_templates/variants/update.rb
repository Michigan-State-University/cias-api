# frozen_string_literal: true

class V1::ReportTemplates::Variants::Update
  def self.call(variant, variant_params)
    new(variant, variant_params).call
  end

  def initialize(variant, variant_params)
    @variant        = variant
    @variant_params = variant_params
  end

  def call
    ActiveRecord::Base.transaction do
      variant.update!(
        variant_params
      )

      other_variants.update_all(preview: false) if variant.preview
    end
  end

  private

  attr_reader :variant, :variant_params

  def other_variants
    ReportTemplate::Section::Variant.to_preview.
      where(report_template_section_id: variant.report_template_section_id).
      where.not(id: variant.id)
  end
end

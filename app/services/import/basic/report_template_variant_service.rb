# frozen_string_literal: true

class Import::Basic::ReportTemplateVariantService
  include ImportOperations
  def self.call(section_id, variant_hash)
    new(
      section_id,
      variant_hash.except(:version)
    ).call
  end

  def initialize(section_id, variant_hash)
    @section_id = section_id
    @variant_hash = variant_hash
    @image = variant_hash.delete(:image)
  end

  attr_reader :variant_hash, :section_id, :image

  def call
    ReportTemplate::Section::Variant.create!(variant_hash.merge({ report_template_section_id: section_id, image: import_file(image) }))
  end
end

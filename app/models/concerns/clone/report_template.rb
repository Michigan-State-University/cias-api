# frozen_string_literal: true

class Clone::ReportTemplate
  attr_accessor :source, :outcome

  def initialize(source, **options)
    @source = source
    @outcome = @source.dup
    options.delete(:session_variables)
    options.delete(:clean_formulas)
    options.delete(:hidden)
    options.delete(:position)
    options.delete(:params)
    @outcome.assign_attributes(options)
    @outcome.name = uniq_name
    @outcome.save!
  end

  def execute
    outcome.is_duplicated = true
    clone_attachments

    source.sections.each do |section|
      new_section = ReportTemplate::Section.new(section.slice(*ReportTemplate::Section::ATTR_NAMES_TO_COPY))
      outcome.sections << new_section

      section.variants.each do |variant|
        new_variant = ReportTemplate::Section::Variant.new(variant.slice(*ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY))
        new_section.variants << new_variant

        new_variant.image.attach(variant.image.blob) if variant.image.attachment
      end
    end
    outcome
  end

  private

  def uniq_name
    number_of_copies = outcome.session.report_templates.where('name like ?', "%#{outcome.name}").count

    case number_of_copies
    when 0
      outcome.name
    when 1
      "Copy of #{outcome.name}"
    else
      "#{number_of_copies.ordinalize} copy of #{outcome.name}"
    end
  end

  def clone_attachments
    outcome.logo.attach(source.logo.blob) if source.logo.attachment
    outcome.pdf_preview.attach(source.pdf_preview.blob) if source.pdf_preview.attachment
  end
end

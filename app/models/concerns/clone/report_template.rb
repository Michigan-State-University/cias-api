# frozen_string_literal: true

class Clone::ReportTemplate
  attr_accessor :source, :outcome, :set_flag

  def initialize(source, options)
    @source = source
    @outcome = @source.dup
    @set_flag = options[:set_flag].nil? ? true : options.delete(:set_flag)
    options.delete(:session_variables)
    options.delete(:clean_formulas)
    options.delete(:hidden)
    options.delete(:position)
    @outcome.assign_attributes(options[:params])
    @outcome.name = uniq_name(@outcome.session.report_templates.map(&:name))
    @outcome.save!
  end

  def execute
    outcome.update!(is_duplicated_from_other_session: true) if different_session? && set_flag
    clone_attachments

    source.sections.each do |section|
      new_section = ReportTemplate::Section.new(section.slice(*ReportTemplate::Section::ATTR_NAMES_TO_COPY))
      outcome.sections << new_section

      section.variants.each do |variant|
        new_variant = ReportTemplate::Section::Variant.new(variant.slice(*ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY))
        new_section.variants << new_variant

        new_variant.image.attach(variant.image.blob) if variant.image.attached?
      end
    end
    outcome
  end

  private

  def uniq_name(occupied_names, suggested_name = default_suggested_name, starting_index = nil)
    return suggested_name unless suggested_name.in?(occupied_names)

    next_suggested_index = starting_index.present? ? starting_index + 1 : outcome.session.report_templates.where('name like ?', "%#{outcome.name}").count

    uniq_name(occupied_names, "#{next_suggested_index.ordinalize} copy of #{outcome.name}", next_suggested_index)
  end

  def default_suggested_name
    source.session_id == outcome.session_id ? "Copy of #{outcome.name}" : outcome.name
  end

  def clone_attachments
    outcome.logo.attach(source.logo.blob) if source.logo.attached?
    outcome.pdf_preview.attach(source.pdf_preview.blob) if source.pdf_preview.attached?
    outcome.cover_letter_custom_logo.attach(source.cover_letter_custom_logo.blob) if source.cover_letter_custom_logo.attached?
  end

  def different_session?
    outcome.session_id != source.session_id
  end
end

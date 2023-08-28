# frozen_string_literal: true

class ReportTemplate < ApplicationRecord
  include Translate
  include ::TranslationAuxiliaryMethods
  include Clone
  has_paper_trail
  extend DefaultValues

  CURRENT_VERSION = '1'

  belongs_to :session, counter_cache: true
  has_many :sections, class_name: 'ReportTemplate::Section', dependent: :destroy
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', through: :sections
  has_many :generated_reports, dependent: :destroy

  attribute :original_text, :json, default: assign_default_values('original_text')

  has_one_attached :logo
  has_one_attached :pdf_preview

  validates :name, :report_for, presence: true
  validates :name, uniqueness: { scope: :session_id }

  delegate :ability_to_update_for?, to: :session

  before_update :cascade_report_template_type_change

  after_destroy :remove_template_from_third_party_questions

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant',
    henry_ford_health: 'henry_ford_health'
  }

  ATTR_NAMES_TO_COPY = %w[
    name report_for summary
  ].freeze

  def translate_summary(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('summary', summary, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_name(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('name', name, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_section_variants(translator, source_language_name_short, destination_language_name_short)
    sections.each do |section|
      section.variants.each do |variant|
        variant.translate(translator, source_language_name_short, destination_language_name_short)
      end
    end
  end

  private

  def remove_template_from_third_party_questions
    session.questions.where(type: 'Question::ThirdParty').find_each do |question|
      question.body_data.each do |data|
        data['report_template_ids'].delete(id)
      end
      question.update!(body: question.body)
    end
  end

  def cascade_report_template_type_change
    remove_template_from_third_party_questions if report_for_was == 'third_party' && report_for != 'third_party'
  end
end

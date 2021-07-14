# frozen_string_literal: true

class SmsPlan < ApplicationRecord
  has_paper_trail
  include Clone
  extend DefaultValues

  belongs_to :session, counter_cache: true
  has_many :variants, class_name: 'SmsPlan::Variant', dependent: :destroy

  attribute :original_text, :json, default: assign_default_values('original_text')

  validates :name, :schedule, :frequency, presence: true

  ATTR_NAMES_TO_COPY = %w[
    name schedule schedule_payload frequency end_at formula no_formula_text is_used_formula
  ].freeze

  enum schedule: {
    days_after_session_end: 'days_after_session_end',
    after_session_end: 'after_session_end'
  }, _suffix: true

  enum frequency: {
    once: 'once',
    once_a_day: 'once_a_day',
    once_a_week: 'once_a_week',
    once_a_month: 'once_a_month'
  }, _suffix: true

  def translate_no_formula_text(translator, source_language_name_short, destination_language_name_short)
    original_text['no_formula_text'] = no_formula_text
    new_no_formula_text = translator.translate(no_formula_text, source_language_name_short, destination_language_name_short)

    update!(no_formula_text: new_no_formula_text)
  end
end

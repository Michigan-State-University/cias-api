# frozen_string_literal: true

class SmsPlan < ApplicationRecord
  has_paper_trail
  include Clone

  belongs_to :session, counter_cache: true
  has_many :variants, class_name: 'SmsPlan::Variant', dependent: :destroy

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
end

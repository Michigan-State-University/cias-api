# frozen_string_literal: true

class SmsPlan < ApplicationRecord
  has_paper_trail
  include Clone
  include Translate
  include ::TranslationAuxiliaryMethods
  extend DefaultValues

  CURRENT_VERSION = '1'

  has_many :alert_phones, dependent: :destroy
  has_many :phones, through: :alert_phones
  belongs_to :session, counter_cache: true
  has_many :variants, class_name: 'SmsPlan::Variant', dependent: :destroy
  has_one_attached :no_formula_attachment, dependent: :purge_later

  attribute :original_text, :json, default: -> { assign_default_values('original_text') }

  validates :name, :schedule, :frequency, presence: true

  delegate :ability_to_update_for?, to: :session

  scope :limit_to_types, ->(types) { where(type: types) if types.present? }

  ATTR_NAMES_TO_COPY = %w[
    name schedule schedule_payload frequency end_at formula no_formula_text is_used_formula
    include_first_name include_last_name include_email include_phone_number type
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
    translate_attribute('no_formula_text', no_formula_text, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_variants(translator, src_language_name_short, dest_language_name_short)
    variants.each { |variant| variant.translate(translator, src_language_name_short, dest_language_name_short) }
  end

  def include_full_name?
    include_first_name && include_last_name
  end

  def no_data_included?
    !include_last_name && !include_first_name && !include_email && !include_phone_number
  end

  def alert?
    type.eql? 'SmsPlan::Alert'
  end

  def ability_to_clone?
    true
  end

  def self.detailed_search(params)
    scope = all
    scope.limit_to_types(params[:types])
  end
end

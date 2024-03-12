# frozen_string_literal: true

class SmsPlan::Variant < ApplicationRecord
  include ::TranslationAuxiliaryMethods
  has_paper_trail
  belongs_to :sms_plan
  has_one_attached :attachment, dependent: :purge_later

  CURRENT_VERSION = '1'

  attribute :original_text, :json, default: -> { { 'content' => '' } }

  before_create :assign_position

  default_scope { order(:position) }

  ATTR_NAMES_TO_COPY = %w[formula_match content].freeze

  def translate(translator, src_language_name_short, dest_language_name_short)
    translate_attribute('content', content, translator, src_language_name_short, dest_language_name_short)
  end

  private

  def assign_position
    self.position = sms_plan.variants.count
  end
end

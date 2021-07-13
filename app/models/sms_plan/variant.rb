# frozen_string_literal: true

class SmsPlan::Variant < ApplicationRecord
  include Translate
  has_paper_trail
  belongs_to :sms_plan

  attribute :original_text, :json, default: { 'content' => {} }

  ATTR_NAMES_TO_COPY = %w[formula_match content].freeze

  def translate(translator, src_language_name_short, dest_language_name_short)
    original_text['content'] = content
    new_content = translator.translate(content, src_language_name_short, dest_language_name_short)

    update!(content: new_content)
  end
end

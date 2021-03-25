# frozen_string_literal: true

class SmsPlan::Variant < ApplicationRecord
  belongs_to :sms_plan

  ATTR_NAMES_TO_COPY = %w[formula_match content].freeze
end

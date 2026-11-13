# frozen_string_literal: true

class SmsOptOut < ApplicationRecord
  OPT_OUT_KEYWORDS = %w[STOP STOPALL UNSUBSCRIBE CANCEL QUIT OPTOUT REVOKE].freeze
  OPT_IN_KEYWORDS = %w[START UNSTOP].freeze

  belongs_to :user

  validates :opted_out_at, presence: true
end

# frozen_string_literal: true

class UserLogRequest < ApplicationRecord
  has_paper_trail
  belongs_to :user, optional: true

  delegate :to_s, to: :id
end

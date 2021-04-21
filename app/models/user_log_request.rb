# frozen_string_literal: true

class UserLogRequest < ApplicationRecord
  belongs_to :user, optional: true

  delegate :to_s, to: :id
end

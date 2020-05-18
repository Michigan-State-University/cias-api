# frozen_string_literal: true

class UserLogRequest < ApplicationRecord
  belongs_to :user

  delegate :to_s, to: :id
end

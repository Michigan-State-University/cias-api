# frozen_string_literal: true

class Message < ApplicationRecord
  validates :phone, :body, presence: true
end

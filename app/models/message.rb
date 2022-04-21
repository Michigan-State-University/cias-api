# frozen_string_literal: true

class Message < ApplicationRecord
  has_paper_trail skip: %i[phone]
  validates :phone, :body, presence: true

  encrypts :phone
end

# frozen_string_literal: true

class Message < ApplicationRecord
  has_paper_trail skip: %i[phone]
  validates :phone, :body, presence: true
  belongs_to :question, optional: true

  has_encrypted :phone
end

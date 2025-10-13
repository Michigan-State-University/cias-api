# frozen_string_literal: true

class Message < ApplicationRecord
  has_paper_trail skip: %i[phone]
  validates :phone, :body, presence: true

  audited except: %i[phone phone_ciphertext]
  has_encrypted :phone
end

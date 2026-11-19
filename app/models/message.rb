# frozen_string_literal: true

class Message < ApplicationRecord
  has_paper_trail skip: %i[phone phone_ciphertext body]
  validates :phone, :body, presence: true
  belongs_to :question, optional: true

  audited except: %i[phone phone_ciphertext body]
  has_encrypted :phone
end

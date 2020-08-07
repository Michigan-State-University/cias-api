# frozen_string_literal: true

class Problem < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :interventions, dependent: :restrict_with_exception

  validates :name, presence: true

  aasm.attribute_name :status
  aasm do
    state :draft, initial: true
    state :published, :closed

    event :broadcast do
      transitions from: :draft, to: :published
    end

    event :close do
      transitions from: :published, to: :closed
    end
  end

  scope :allow_guests, -> { where(allow_guests: true) }
end

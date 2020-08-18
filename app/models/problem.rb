# frozen_string_literal: true

class Problem < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :interventions, dependent: :restrict_with_exception

  attr_accessor :status_event

  validates :name, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close to_archive] }, allow_nil: true

  aasm.attribute_name :status
  aasm do
    state :draft, initial: true
    state :published, :closed, :archived

    event :broadcast do
      transitions from: :draft, to: :published
    end

    event :close do
      transitions from: :published, to: :closed
    end

    event :to_archive do
      transitions from: :closed, to: :archived
    end
  end

  scope :allow_guests, -> { where(allow_guests: true) }

  def export_answers_as(type:)
    raise ArgumentError, 'Undefined type of data export.' unless %w[csv].include?(type.downcase)

    "Problem::#{type.classify}".constantize.new(self).execute
  end

  def integral_update
    public_send(status_event) unless status_event.nil?
    save!
  end
end

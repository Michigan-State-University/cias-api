# frozen_string_literal: true

class Problem < ApplicationRecord
  include AASM
  include Clone

  belongs_to :user, inverse_of: :problems
  has_many :interventions, dependent: :restrict_with_exception, inverse_of: :problem
  has_many :user_problems, dependent: :restrict_with_exception, inverse_of: :problem
  has_many :users, dependent: :restrict_with_exception, through: :user_problems

  attr_accessor :status_event

  attribute :shared_to, :string, default: 'anyone'

  validates :name, :shared_to, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close to_archive] }, allow_nil: true

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to

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

  def export_answers_as(type:)
    raise ArgumentError, 'Undefined type of data export.' unless %w[csv].include?(type.downcase)

    "Problem::#{type.classify}".constantize.new(self).execute
  end

  def integral_update
    public_send(status_event) unless status_event.nil?
    save!
  end
end

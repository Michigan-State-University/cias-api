# frozen_string_literal: true

class Problem < ApplicationRecord
  include AASM
  include Clone

  belongs_to :user, inverse_of: :problems
  has_many :interventions, dependent: :restrict_with_exception, inverse_of: :problem
  has_many :user_interventions, dependent: :restrict_with_exception, through: :interventions
  has_many :intervention_invitations, dependent: :restrict_with_exception, through: :interventions

  has_many_attached :reports

  attr_accessor :status_event

  attribute :shared_to, :string, default: 'anyone'

  validates :name, :shared_to, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close to_archive] }, allow_nil: true

  scope :available_for_participant, lambda { |participant_id|
    left_joins(:user_interventions).published.not_shared_to_invited
      .or(left_joins(:user_interventions).published.where(user_interventions: { user_id: participant_id }))
  }

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to

  aasm.attribute_name :status
  aasm do
    state :draft, initial: true
    state :published, :closed, :archived

    event :broadcast do
      after { ::Problem::StatusKeeper.new(id).broadcast }
      transitions from: :draft, to: :published
    end

    event :close do
      transitions from: :published, to: :closed
    end

    event :to_archive do
      transitions from: :closed, to: :archived
    end

    event :to_initial do
      transitions from: %i[draft published closed archived], to: :draft
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

  def create_user_interventions(emails)
    users_granted_access_ids = User.where(email: emails).ids
    return if users_granted_access_ids.empty?

    bulk = []
    interventions.ids.each do |intervention_id|
      users_granted_access_ids.each do |user_id|
        h = {}
        h[:user_id] = user_id
        h[:intervention_id] = intervention_id
        timestamp = Time.current
        h[:created_at] = timestamp
        h[:updated_at] = timestamp
        bulk.push(h)
      end
    end
    UserIntervention.insert_all(bulk)
  end
end

# frozen_string_literal: true

class Intervention < ApplicationRecord
  include Clone

  belongs_to :user, inverse_of: :interventions
  has_many :sessions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :user_sessions, dependent: :restrict_with_exception, through: :sessions
  has_many :session_invitations, dependent: :restrict_with_exception, through: :sessions

  has_many_attached :reports

  attr_accessor :status_event

  attribute :shared_to, :string, default: 'anyone'

  validates :name, :shared_to, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close to_archive] }, allow_nil: true

  scope :available_for_participant, lambda { |participant_id|
    left_joins(:user_sessions).published.not_shared_to_invited
      .or(left_joins(:user_sessions).published.where(user_sessions: { user_id: participant_id }))
  }

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to
  enum status: { draft: 'draft', published: 'published', closed: 'closed', archived: 'archived' }

  def broadcast
    return unless draft?

    published!
    ::Intervention::StatusKeeper.new(id).broadcast
  end

  def close
    closed! if published?
  end

  def archive
    archived! if closed? || draft?
  end

  def export_answers_as(type:)
    raise ArgumentError, 'Undefined type of data export.' unless %w[csv].include?(type.downcase)

    "Intervention::#{type.classify}".constantize.new(self).execute
  end

  def integral_update
    public_send(status_event) unless status_event.nil?
    save!
  end

  def create_user_sessions(emails)
    users_granted_access_ids = User.where(email: emails).ids
    return if users_granted_access_ids.empty?

    UserSession.transaction do
      sessions.ids.each do |session_id|
        users_granted_access_ids.each do |user_id|
          UserSession.create!(user_id: user_id, session_id: session_id)
        end
      end
    end
  end
end

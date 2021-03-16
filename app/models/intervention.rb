# frozen_string_literal: true

class Intervention < ApplicationRecord
  include Clone

  belongs_to :user, inverse_of: :interventions
  has_many :sessions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :user_sessions, dependent: :restrict_with_exception, through: :sessions
  has_many :invitations, as: :invitable, dependent: :destroy

  has_many_attached :reports
  has_one_attached :logo

  has_one :logo_attachment, -> { where(name: 'logo') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :logo_blob, through: :logo_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  attr_accessor :status_event

  attribute :shared_to, :string, default: 'anyone'

  validates :name, :shared_to, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close to_archive] }, allow_nil: true

  scope :available_for_participant, lambda { |participant_email|
    left_joins(:invitations).published.not_shared_to_invited
      .or(left_joins(:invitations).published.where(invitations: { email: participant_email }))
  }

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to
  enum status: { draft: 'draft', published: 'published', closed: 'closed', archived: 'archived' }

  def broadcast
    return unless draft?

    published!
    ::Intervention::PublishJob.perform_later(id)
  end

  def close
    closed! if published?
  end

  def to_archive
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

  def give_user_access(emails)
    return if emails.empty?

    Invitation.transaction do
      emails.each do |email|
        invitations.create!(email: email)
      end
    end
  end

  def newest_report
    reports.attachments.order(created_at: :desc).first
  end
end

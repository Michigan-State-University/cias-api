# frozen_string_literal: true

class Intervention < ApplicationRecord
  has_paper_trail
  include Clone
  include Translate
  extend DefaultValues

  belongs_to :user, inverse_of: :interventions
  belongs_to :organization, optional: true
  belongs_to :google_language
  has_many :sessions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :user_sessions, dependent: :restrict_with_exception, through: :sessions
  has_many :invitations, as: :invitable, dependent: :destroy

  has_many_attached :reports
  has_one_attached :logo, dependent: :purge_later

  has_one :logo_attachment, -> { where(name: 'logo') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :logo_blob, through: :logo_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  attribute :shared_to, :string, default: 'anyone'

  validates :name, :shared_to, presence: true

  scope :available_for_participant, lambda { |participant_email|
    left_joins(:invitations).published.not_shared_to_invited
      .or(left_joins(:invitations).published.where(invitations: { email: participant_email }))
  }
  scope :with_any_organization, -> { where.not(organization_id: nil) }
  scope :indexing, ->(ids) { where(id: ids) }
  scope :limit_to_statuses, ->(statuses) { where(status: statuses) if statuses.present? }
  scope :filter_by_starts_with, ->(name) { where('name like ?', "#{name}%") if name.present?}

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to
  enum status: { draft: 'draft', published: 'published', closed: 'closed', archived: 'archived' }

  before_validation :assign_default_google_language
  after_update_commit :status_change

  def assign_default_google_language
    self.google_language = GoogleLanguage.find_by(language_code: 'en') if google_language.nil?
  end

  def status_change
    return unless saved_change_to_attribute?(:status)

    ::Interventions::PublishJob.perform_later(id) if status == 'published'
  end

  def export_answers_as(type:)
    raise ArgumentError, 'Undefined type of data export.' unless %w[csv].include?(type.downcase)

    ::Intervention::Csv.call(self)
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

  def translation_prefix(destination_language_name_short)
    update!(name: "(#{destination_language_name_short.upcase}) #{name}")
  end

  def translate_sessions(translator, source_language_name_short, destination_language_name_short)
    sessions.each do |session|
      session.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def cache_key
    "intervention/#{id}-#{updated_at&.to_s(:number)}"
  end
  
  def self.detailed_search(params)
    scope = all
    scope = scope.limit_to_statuses(params[:statuses])
    scope.filter_by_starts_with(params[:name])
  end
end

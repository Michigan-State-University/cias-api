# frozen_string_literal: true

class Intervention < ApplicationRecord
  has_paper_trail
  include Clone
  include Translate
  extend DefaultValues

  belongs_to :user, inverse_of: :interventions
  belongs_to :organization, optional: true
  belongs_to :google_language
  has_many :user_interventions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :sessions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :user_sessions, dependent: :restrict_with_exception, through: :sessions
  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :intervention_accesses, dependent: :destroy

  has_many_attached :reports
  has_many_attached :files
  has_one_attached :logo, dependent: :purge_later

  has_one :logo_attachment, -> { where(name: 'logo') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :logo_blob, through: :logo_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  attribute :shared_to, :string, default: 'anyone'
  attribute :original_text, :json, default: { additional_text: '' }

  validates :name, :shared_to, presence: true
  validate :cat_sessions_validation, if: :published?
  validate :cat_settings_validation, if: :published?

  scope :available_for_participant, lambda { |participant_email|
    left_joins(:intervention_accesses).published.not_shared_to_invited
      .or(left_joins(:intervention_accesses).published.where(intervention_accesses: { email: participant_email }))
  }
  scope :with_any_organization, -> { where.not(organization_id: nil) }
  scope :indexing, ->(ids) { where(id: ids) }
  scope :limit_to_statuses, ->(statuses) { where(status: statuses) if statuses.present? }
  scope :filter_by_name, ->(name) { where('lower(name) like ?', "%#{name.downcase}%") if name.present? }

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to
  enum status: { draft: 'draft', published: 'published', closed: 'closed', archived: 'archived' }
  enum license_type: { limited: 'limited', unlimited: 'unlimited' }, _prefix: :license_type

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

  def invite_by_email(emails, health_clinic_id = nil)
    users_exists = ::User.where(email: emails)
    (emails - users_exists.map(&:email)).each do |email|
      User.invite!(email: email)
    end

    Invitation.transaction do
      User.where(email: emails).find_each do |user|
        invitations.create!(email: user.email, health_clinic_id: health_clinic_id)
      end
    end

    Interventions::InvitationJob.perform_later(id, emails, health_clinic_id)
  end

  def give_user_access(emails)
    return if emails.empty?

    InterventionAccess.transaction do
      emails.each { |email| InterventionAccess.create!(intervention_id: id, email: email) }
    end
  end

  def newest_report
    reports.attachments.order(created_at: :desc).first
  end

  def translation_prefix(destination_language_name_short)
    update!(name: "(#{destination_language_name_short.upcase}) #{name}")
  end

  def translate_additional_text(translator, source_language_name_short, destination_language_name_short)
    original_text['additional_text'] = additional_text
    new_additional_text = translator.translate(additional_text, source_language_name_short, destination_language_name_short)

    update!(additional_text: new_additional_text)
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
    scope.filter_by_name(params[:name])
  end

  def cat_sessions_validation
    sessions.where(type: 'Session::CatMh').find_each do |session|
      errors[:base] << (I18n.t 'activerecord.errors.models.intervention.attributes.cat_mh_resources', session_id: session.id) unless session.contains_necessary_resources? # rubocop:disable Layout/LineLength
    end
  end

  def can_have_files?
    false
  end

  def module_intervention?
    false
  end

  def cat_settings_validation
    return if !intervention_have_cat_mh_sessions? || (cat_mh_application_id.present? && cat_mh_organization_id.present?)

    errors[:base] << (I18n.t 'activerecord.errors.models.intervention.attributes.cat_mh_setting') if license_type_limited? && (cat_mh_pool.blank? || cat_mh_pool.negative?)  # rubocop:disable Layout/LineLength
  end

  def intervention_have_cat_mh_sessions?
    sessions.where(type: 'Session::CatMh').any?
  end
end

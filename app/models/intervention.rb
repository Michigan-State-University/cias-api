# frozen_string_literal: true

class Intervention < ApplicationRecord
  has_paper_trail
  include Intervention::StatusesTransition
  include Clone
  include Translate
  include InvitationInterface
  include TranslationAuxiliaryMethods
  include MessageHandler
  extend DefaultValues

  CURRENT_VERSION = '1'

  belongs_to :user, inverse_of: :interventions
  belongs_to :organization, optional: true
  belongs_to :google_language
  has_many :user_interventions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :sessions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :user_sessions, dependent: :restrict_with_exception, through: :sessions
  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :intervention_accesses, dependent: :destroy
  has_many :stars, dependent: :destroy
  has_one :navigator_setup, class_name: 'LiveChat::Interventions::NavigatorSetup', dependent: :destroy
  has_many :conversations, class_name: 'LiveChat::Conversation', dependent: :restrict_with_exception
  has_many :live_chat_navigator_invitations, class_name: 'LiveChat::Interventions::NavigatorInvitation', dependent: :destroy
  has_many :intervention_navigators, class_name: 'LiveChat::Interventions::Navigator', dependent: :destroy
  has_many :navigators, through: :intervention_navigators, source: :user
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :live_chat_summoning_users, class_name: 'LiveChat::SummoningUser', dependent: :destroy
  has_many :predefined_user_parameters, dependent: :destroy
  has_many :predefined_users, through: :predefined_user_parameters, source: :user

  has_many :collaborators, dependent: :destroy, inverse_of: :intervention
  belongs_to :current_editor, class_name: 'User', optional: true

  has_many_attached :reports, dependent: :purge_later # generated csv files for the researcher
  has_many_attached :files # files for the participant added in modular intervention
  has_one_attached :logo, dependent: :purge_later

  has_one_attached :exported_data, dependent: :purge_later

  has_many :short_links, as: :linkable, dependent: :destroy

  has_one :logo_attachment, -> { where(name: 'logo') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :logo_blob, through: :logo_attachment, class_name: 'ActiveStorage::Blob', source: :blob
  has_one_attached :conversations_transcript, dependent: :purge_later

  # Henry Ford integration
  has_many :intervention_locations, dependent: :destroy
  has_many :clinic_locations, through: :intervention_locations

  attribute :shared_to, :string, default: 'anyone'
  attribute :original_text, :json, default: { additional_text: '' }

  delegate :language_code, to: :google_language

  validates :name, :shared_to, presence: true
  validate :cat_sessions_validation, if: :published?
  validate :cat_settings_validation, if: :published?
  validate :live_chat_validation

  scope :available_for_participant, lambda { |participant_email|
    left_joins(:intervention_accesses).published.not_shared_to_invited
                                      .or(left_joins(:intervention_accesses).published.where(intervention_accesses: { email: participant_email }))
  }

  scope :only_visible, -> { where(is_hidden: false) }
  scope :with_any_organization, -> { where.not(organization_id: nil) }
  scope :indexing, ->(ids) { where(id: ids) }
  scope :limit_to_statuses, ->(statuses) { where(status: statuses) if statuses.present? }
  scope :filter_by_name, ->(name) { where('lower(name) like ?', "%#{name.downcase}%") if name.present? }
  scope :filter_by_organization, ->(organization_id) { where(organization_id: organization_id) }
  scope :only_shared_with_me, ->(user_id) { joins(:collaborators).where(collaborators: { user_id: user_id }) }
  scope :only_shared_by_me, ->(user_id) { joins(:collaborators).where(user_id: user_id) }
  scope :only_not_shared_with_anyone, ->(user_id) { left_joins(:collaborators).where(user_id: user_id, collaborators: { id: nil }) }
  scope :only_starred_by_me, ->(user) { where(id: user.stars.pluck(:intervention_id)) }

  enum shared_to: { anyone: 'anyone', registered: 'registered', invited: 'invited' }, _prefix: :shared_to
  enum status: STATUSES
  enum license_type: { limited: 'limited', unlimited: 'unlimited' }, _prefix: :license_type
  enum current_narrator: { peedy: 0, emmi: 1 }
  enum sensitive_data_state: { collected: 'collected', marked_to_remove: 'marked_to_remove', removed: 'removed' }, _prefix: :sensitive_data

  before_validation :assign_default_google_language
  before_save :create_navigator_setup, if: -> { live_chat_enabled && navigator_setup.nil? }
  before_save :remove_short_links, if: :will_save_change_to_organization_id?
  before_update :cascade_access_type_change, if: :shared_to_changed?
  after_update_commit :status_change, :hf_access_change

  def assign_default_google_language
    self.google_language = GoogleLanguage.find_by(language_code: 'en') if google_language.nil?
  end

  def status_change
    return unless saved_change_to_attribute?(:status)

    if published? && paused_at.present?
      ::Interventions::RePublishJob.perform_later(id)
    elsif published?
      ::Interventions::PublishJob.perform_later(id)
    elsif paused?
      ::Interventions::PauseJob.perform_later(id)
    end
  end

  def hf_access_change
    return unless saved_change_to_attribute?(:hfhs_access)
    return if hfhs_access

    ::Question::HenryFordInitial.joins(:question_group).where(question_groups: { session: sessions }).delete_all
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
    emails.map!(&:downcase)

    if shared_to != 'anyone'
      existing_users_emails, non_existing_users_emails = split_emails_exist(emails)
      invite_non_existing_users(non_existing_users_emails, true, [:participant], language_code)
    end

    if shared_to_invited?
      emails_without_access = emails - intervention_accesses.map(&:email).map(&:downcase)
      give_user_access(emails_without_access)
    end

    Invitation.transaction do
      User.where(email: emails).find_each do |user|
        invitations.create!(email: user.email, health_clinic_id: health_clinic_id)
      end
    end

    SendFillInvitation::InterventionJob.perform_later(id, existing_users_emails || emails, non_existing_users_emails || [], health_clinic_id)
  end

  def give_user_access(emails)
    return if emails.empty?

    InterventionAccess.transaction do
      emails.each { |email| InterventionAccess.create!(intervention_id: id, email: email.downcase) }
    end
  end

  def newest_report
    reports.attachments.order(created_at: :desc).first
  end

  def cache_key
    "intervention/#{id}-#{updated_at&.to_s(:number)}"
  end

  def self.detailed_search(params, user)
    scope = filter_by_collaboration_type(params, user)
    scope = scope.limit_to_statuses(params[:statuses])
    scope = scope.filter_by_organization(params[:organization_id]) if params[:organization_id].present?
    scope = scope.only_starred_by_me(user) if params[:starred].present?
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

  def starred_by?(user_id)
    stars.find_by(user_id: user_id).present?
  end

  def create_navigator_setup
    self.navigator_setup = LiveChat::Interventions::NavigatorSetup.new
  end

  def cat_settings_validation
    return if !intervention_have_cat_mh_sessions? || (cat_mh_application_id.present? && cat_mh_organization_id.present?)

    errors[:base] << (I18n.t 'activerecord.errors.models.intervention.attributes.cat_mh_setting') if license_type_limited? && (cat_mh_pool.blank? || cat_mh_pool.negative?) # rubocop:disable Layout/LineLength
  end

  def live_chat_validation
    return if status == 'published' || status == 'draft'

    errors[:base] << I18n.t('activerecord.errors.models.intervention.attributes.live_chat_wrong_session_status') if live_chat_enabled
  end

  def intervention_have_cat_mh_sessions?
    sessions.where(type: 'Session::CatMh').any?
  end

  def translation_prefix(destination_language_name_short)
    update!(name: "(#{destination_language_name_short.upcase}) #{name}")
  end

  def translate_additional_text(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('additional_text', additional_text, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_logo_description(translator, source_language_name_short, destination_language_name_short)
    return unless logo.attached?

    original_text['image_alt'] = logo_blob.description

    new_value = translator.translate(logo_blob.description, source_language_name_short, destination_language_name_short)
    logo_blob.update!(description: new_value)
  end

  def translate_sessions(translator, source_language_name_short, destination_language_name_short)
    sessions.each do |session|
      session.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def navigators_from_team
    id_scope = user.team_admin? ? user.admins_teams.pluck(:id) : user.team_id
    User.limit_to_roles('navigator').where(team_id: id_scope) if id_scope.present?
  end

  def ability_to_clone?
    true
  end

  def ability_to_update_for?(user)
    return true unless collaborators.any?

    collaborator = collaborators.find_by(user_id: user.id)

    current_editor_id == user.id && (collaborator.present? ? collaborator.edit : true)
  end

  def remove_short_links
    short_links.destroy_all
  end

  def cascade_access_type_change
    return unless shared_to == 'anyone'

    permitted_schedules = %w[after_fill immediately]

    sessions.each do |session|
      next if session.schedule.in?(permitted_schedules)

      session.update!(
        schedule: 'after_fill',
        schedule_payload: nil,
        schedule_at: nil
      )
    end
  end

  def self.filter_by_collaboration_type(params, user)
    scope = all
    scope = scope.only_shared_with_me(user.id) if params[:only_shared_with_me].present?
    scope = scope.only_shared_by_me(user.id) if params[:only_shared_by_me].present?
    scope = scope.only_not_shared_with_anyone(user.id) if params[:only_not_shared_with_anyone].present?
    scope
  end
end

# frozen_string_literal: true

class Session < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include Clone
  include FormulaInterface
  include InvitationInterface
  include Translate
  include ::TranslationAuxiliaryMethods

  CURRENT_VERSION = '1'

  belongs_to :intervention, inverse_of: :sessions, touch: true, counter_cache: true
  belongs_to :google_tts_voice, optional: true
  belongs_to :google_language, optional: true

  has_many :sms_plans, dependent: :destroy

  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :report_templates, dependent: :destroy

  has_many :user_sessions, dependent: :destroy, inverse_of: :session
  has_many :users, through: :user_sessions
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :question_groups, dependent: :destroy, inverse_of: :session
  has_many :question_group_plains, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Plain'
  has_one :question_group_initial, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Initial'
  has_one :question_group_finish, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Finish'
  has_many :questions, through: :question_groups
  has_many :answers, dependent: :destroy, through: :questions
  has_many :sms_codes, dependent: :destroy

  attribute :settings, :json, default: -> { assign_default_values('settings') }
  attribute :position, :integer, default: 1
  attribute :formulas, :json, default: -> { assign_default_values('formulas') }
  attribute :body, :json, default: -> { assign_default_values('body') }
  attribute :original_text, :json, default: -> { { name: '' } }

  enum :schedule, { days_after: 'days_after',
                    days_after_fill: 'days_after_fill',
                    exact_date: 'exact_date',
                    after_fill: 'after_fill',
                    days_after_date: 'days_after_date',
                    immediately: 'immediately' }, prefix: :schedule
  enum :current_narrator, ::Intervention.current_narrators

  delegate :published?, to: :intervention
  delegate :draft?, to: :intervention
  delegate :ability_to_update_for?, to: :intervention
  delegate :language_code, to: :google_language

  scope :multiple_fill, -> { where(multiple_fill: true) }

  validates :name, :variable, presence: true
  validates :last_report_template_number, presence: true
  validates :settings, json: { schema: lambda {
                                         File.read(Rails.root.join("#{json_schema_path}/settings.json").to_s)
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :formulas, json: { schema: lambda {
                                         File.read(Rails.root.join("#{json_schema_path}/formula.json").to_s)
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :unique_variable, on: %i[create update]
  validates :autofinish_delay, presence: true, if: :autofinish_enabled
  validates :autofinish_delay, numericality: { greater_than_or_equal_to: 0 }
  validates :autoclose_at, presence: true, if: :autoclose_enabled

  after_initialize :set_sms_defaults
  before_validation :set_default_variable
  after_create :assign_default_tts_voice
  after_create :assign_default_google_language

  accepts_nested_attributes_for :sms_codes

  def sms_session_type?
    type.match?('Session::Sms')
  end

  def position_greater_than
    @position_greater_than ||= intervention.sessions.where('position > ?', position).order(:position)
  end

  def next_session
    intervention.sessions.where.not(type: 'Session::Sms').order(position: :asc).find_by('position > ?', position)
  end

  def last_session?
    next_session.blank?
  end

  def integral_update
    return if published?

    save!
  end

  def invite_by_email(emails, health_clinic_id = nil)
    emails.map!(&:downcase)

    if intervention.shared_to != 'anyone'
      existing_users_emails, non_existing_users_emails = split_emails_exist(emails)
      invite_non_existing_users(non_existing_users_emails, true, [:participant], intervention.language_code)
    end

    if intervention.shared_to_invited?
      emails_without_access = emails - intervention.intervention_accesses.map { |access| access.email&.downcase }
      intervention.give_user_access(emails_without_access)
    end

    ActiveRecord::Base.transaction do
      users = User.where(email: emails)
      users.find_each do |user|
        invitations.create!(email: user.email, health_clinic_id: health_clinic_id)
        user.update!(quick_exit_enabled: intervention.quick_exit)

        user_intervention = UserIntervention.find_or_create_by(user_id: user.id, intervention_id: intervention.id, health_clinic_id: health_clinic_id)
        user_session = UserSession.find_or_create_by(
          session_id: id,
          user_id: user.id,
          health_clinic_id: health_clinic_id,
          type: user_session_type,
          user_intervention_id: user_intervention.id
        )
        user_intervention.update!(status: 'in_progress') if user_session.started && (user_session.scheduled_at.blank? || user_session.scheduled_at.past?)
      end

      (emails - users.map(&:email)).each do |email|
        invitations.create!(email: email, health_clinic_id: health_clinic_id)
      end
    end

    _, non_existing_users_emails = split_emails_exist(emails) if intervention.shared_to_anyone?

    SendFillInvitation::SessionJob.perform_later(id, existing_users_emails || emails, non_existing_users_emails || [], health_clinic_id, intervention_id)
  end

  def send_link_to_session(user, health_clinic = nil)
    return if !intervention.published? || user.with_invalid_email? || user.email_notification.blank?

    SessionMailer.with(locale: language_code).inform_to_an_email(self, user.email, health_clinic).deliver_later
  end

  def send_sms_to_session(user, health_clinic = nil)
    return if !intervention.published? || user.sms_notification.blank?
    return if user.phone.blank? || (!user.phone.confirmed? && user.roles.exclude?('predefined_participant'))

    content = I18n.t('sessions.reminder', intervention_name: intervention.name, link: ::V1::SessionOrIntervention::Link.call(self, health_clinic, user.email))
    sms = Message.create(phone: user.phone.full_number, body: content)
    Communication::Sms.new(sms.id).send_message
  end

  def available_now?(participant_date_with_payload = nil)
    return true if schedule == 'after_fill'
    return true if %w[days_after exact_date].include?(schedule) && schedule_at.noon.past?
    return true if schedule == 'days_after_date' && participant_date_with_payload&.noon&.past?

    false
  end

  def increment_and_get_last_report_template_number
    self.last_report_template_number += 1
    save!
    self.last_report_template_number
  end

  def clear_formulas
    self.formulas = self.class.assign_default_values('formulas')
    settings['formula'] = false
  end

  def translate_name(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('name', name, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_sms_plans(translator, source_language_name_short, destination_language_name_short)
    sms_plans.each do |sms_plan|
      sms_plan.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def translate_report_templates(translator, source_language_name_short, destination_language_name_short)
    report_templates.each do |report_template|
      report_template.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def user_session_type
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def fetch_variables(_filter_options = {}, _filtered_question_id = nil)
    raise NotImplementedError, "Subclass of Session did not define #{__method__}"
  end

  def same_as_intervention_language?(session_voice)
    voice_name = session_voice&.google_tts_language&.language_name
    google_lang_name = intervention.google_language.language_name
    # chinese languages are the only ones not following the convention so this check is needed...
    voice_name&.include?('Chinese') ? google_lang_name.include?('Chinese') : voice_name&.include?(google_lang_name)
  end

  private

  def assign_default_tts_voice
    self.google_tts_voice = GoogleTtsVoice.standard_voices.find_by(language_code: 'en-US') if google_tts_voice.nil? && type == 'Session::Classic'
    save!
  end

  def assign_default_google_language
    self.google_language = intervention.google_language if google_language.nil?
    save!
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/session'
  end

  def unique_variable
    return unless ::Session.where.not(id: id).where(intervention: intervention).exists?(variable: variable)

    errors.add(:variable, :already_exists)
  end

  def set_default_variable
    return if variable.present?

    default_variable = loop do
      default_variable = "s#{rand(1..9999)}"
      break default_variable unless ::Session.exists?(variable: default_variable, intervention: intervention)
    end
    self.variable = default_variable
  end

  def set_sms_defaults
    return unless sms_session_type?

    self.default_response ||= I18n.t('sessions.default_response')
    self.welcome_message ||= I18n.t('sessions.welcome_message')
  end
end

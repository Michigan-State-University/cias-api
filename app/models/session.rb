# frozen_string_literal: true

class Session < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include Clone
  include FormulaInterface
  include InvitationInterface
  include Translate

  CURRENT_VERSION = '1'

  belongs_to :intervention, inverse_of: :sessions, touch: true, counter_cache: true
  belongs_to :google_tts_voice, optional: true

  has_many :sms_plans, dependent: :destroy

  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :report_templates, dependent: :destroy

  has_many :user_sessions, dependent: :destroy, inverse_of: :session
  has_many :users, through: :user_sessions
  has_many :notifications, as: :notifiable, dependent: :destroy

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 1
  attribute :formulas, :json, default: assign_default_values('formulas')
  attribute :body, :json, default: assign_default_values('body')
  attribute :original_text, :json, default: { name: '' }

  enum schedule: { days_after: 'days_after',
                   days_after_fill: 'days_after_fill',
                   exact_date: 'exact_date',
                   after_fill: 'after_fill',
                   days_after_date: 'days_after_date',
                   immediately: 'immediately' },
       _prefix: :schedule
  enum current_narrator: ::Intervention.current_narrators

  delegate :published?, to: :intervention
  delegate :draft?, to: :intervention
  delegate :ability_to_update_for?, to: :intervention

  scope :multiple_fill, -> { where(multiple_fill: true) }

  validates :name, :variable, presence: true
  validates :last_report_template_number, presence: true
  validates :settings, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/settings.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :formulas, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/formula.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :unique_variable, on: %i[create update]
  validates :autofinish_delay, presence: true, if: :autofinish_enabled
  validates :autofinish_delay, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_default_variable
  after_create :assign_default_tts_voice

  def position_greater_than
    @position_greater_than ||= intervention.sessions.where('position > ?', position).order(:position)
  end

  def next_session
    intervention.sessions.order(position: :asc).find_by('position > ?', position)
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
      invite_non_existing_users(non_existing_users_emails, true)
    end

    if intervention.shared_to_invited?
      emails_without_access = emails - intervention.intervention_accesses.map(&:email).map(&:downcase)
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
        if user_session.finished_at.blank? && (user_session.scheduled_at.blank? || user_session.scheduled_at.past?)
          user_intervention.update!(status: 'in_progress')
        end
      end
    end

    SendFillInvitation::SessionJob.perform_later(id, existing_users_emails || emails, non_existing_users_emails || [], health_clinic_id, intervention_id)
  end

  def send_link_to_session(user, health_clinic = nil)
    return if !intervention.published? || user.with_invalid_email? || user.email_notification.blank?

    SessionMailer.inform_to_an_email(self, user.email, health_clinic).deliver_later
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
    original_text['name'] = name
    new_name = translator.translate(name, source_language_name_short, destination_language_name_short)

    update!(name: new_name)
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

  def fetch_variables(_filter_options = {})
    raise NotImplementedError, "Subclass of Session did not define #{__method__}"
  end

  def same_as_intervention_language(session_voice)
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
end

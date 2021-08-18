# frozen_string_literal: true

class Session < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include Clone
  include FormulaInterface
  include Translate

  belongs_to :intervention, inverse_of: :sessions, touch: true
  belongs_to :google_tts_voice, optional: true

  has_many :sms_plans, dependent: :destroy

  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :report_templates, dependent: :destroy

  has_many :user_sessions, dependent: :destroy, inverse_of: :session
  has_many :users, through: :user_sessions

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 1
  attribute :formula, :json, default: assign_default_values('formula')
  attribute :original_text, :json, default: { name: '' }

  enum schedule: { days_after: 'days_after',
                   days_after_fill: 'days_after_fill',
                   exact_date: 'exact_date',
                   after_fill: 'after_fill',
                   days_after_date: 'days_after_date' },
       _prefix: :schedule

  delegate :published?, to: :intervention
  delegate :draft?, to: :intervention

  validates :name, :variable, presence: true
  validates :last_report_template_number, presence: true
  validates :settings, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/settings.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :formula, presence: true, json: { schema: lambda {
                                                        Rails.root.join("#{json_schema_path}/formula.json").to_s
                                                      }, message: lambda { |err|
                                                                    err
                                                                  } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :unique_variable, on: %i[create update]

  before_validation :set_default_variable
  after_create :assign_default_tts_voice

  def position_greater_than
    @position_greater_than ||= intervention.sessions.where('position > ?', position).order(:position)
  end

  def next_session
    intervention.sessions.find_by(position: position + 1)
  end

  def integral_update
    return if published?

    propagate_settings
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

    SessionJobs::Invitation.perform_later(id, emails, health_clinic_id)
  end

  def send_link_to_session(user, health_clinic = nil)
    return if !intervention.published? || user.with_invalid_email? || user.email_notification.blank?

    SessionMailer.inform_to_an_email(self, user.email, health_clinic).deliver_later
  end

  def available_now?(participant_date = nil)
    return true if schedule == 'after_fill'
    return true if %w[days_after exact_date].include?(schedule) && schedule_at.noon.past?
    return true if schedule == 'days_after_date' && participant_date&.noon&.past?

    false
  end

  def increment_and_get_last_report_template_number
    self.last_report_template_number += 1
    save!
    self.last_report_template_number
  end

  def clear_formula
    self.formula = self.class.assign_default_values('formula')
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

  private

  def assign_default_tts_voice
    self.google_tts_voice = GoogleTtsVoice.find_by(language_code: 'en-US') if google_tts_voice.nil?
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

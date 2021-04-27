# frozen_string_literal: true

class Session < ApplicationRecord
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :intervention, inverse_of: :sessions, touch: true
  belongs_to :google_tts_voice

  has_many :question_groups, dependent: :destroy, inverse_of: :session
  has_many :question_group_plains, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Plain'
  has_one :question_group_finish, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Finish'
  has_many :sms_plans, dependent: :destroy

  has_many :questions, dependent: :destroy, through: :question_groups
  has_many :answers, dependent: :destroy, through: :questions
  has_many :invitations, as: :invitable, dependent: :destroy
  has_many :report_templates, dependent: :destroy

  has_many :user_sessions, dependent: :destroy, inverse_of: :session
  has_many :users, through: :user_sessions

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 1
  attribute :formula, :json, default: assign_default_values('formula')
  attribute :body, :json, default: assign_default_values('body')

  enum schedule: { days_after: 'days_after', days_after_fill: 'days_after_fill', exact_date: 'exact_date', after_fill: 'after_fill', days_after_date: 'days_after_date' }, _prefix: :schedule

  delegate :published?, to: :intervention
  delegate :draft?, to: :intervention

  validates :name, :variable, presence: true
  validates :last_report_template_number, presence: true
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :unique_variable, on: %i[create update]

  before_validation :set_default_variable
  after_commit :create_core_childs, on: :create

  after_update_commit do
    SessionJob::ReloadAudio.perform_later(id) if saved_change_to_attribute?(:google_tts_voice_id)
  end

  def position_less_than
    @position_less_than ||= intervention.sessions.where(position: ...position).order(:position)
  end

  def position_grather_than
    @position_grather_than ||= intervention.sessions.where('position > ?', position).order(:position)
  end

  def next_session
    intervention.sessions.find_by(position: position + 1)
  end

  def propagate_settings
    return unless settings_changed?

    narrator = (settings['narrator'].to_a - settings_was['narrator'].to_a).to_h
    questions.each do |question|
      question.narrator['settings'].merge!(narrator)
      question.execute_narrator
      question.save!
    end
  end

  def integral_update
    return if published?

    propagate_settings
    save!
  end

  def perform_narrator_reflection(_placeholder)
    nil
  end

  def invite_by_email(emails)
    users_exists = ::User.where(email: emails)
    (emails - users_exists.pluck(:email)).each do |email|
      User.invite!(email: email)
    end

    Invitation.transaction do
      User.where(email: emails).find_each do |user|
        invitations.create!(email: user.email)
      end
    end

    SessionJob::Invitation.perform_later(id, emails)
  end

  def send_link_to_session(user)
    return if !intervention.published? || user.with_invalid_email? || user.email_notification.blank?

    SessionMailer.inform_to_an_email(self, user.email).deliver_later
  end

  def first_question
    question_groups.where('questions_count > 0').order(:position).first.questions.order(:position).first
  end

  def finish_screen
    question_group_finish.questions.first
  end

  def available_now(participant_date = nil)
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

  def session_variables
    [].tap do |array|
      question_groups.each do |question_group|
        question_group.questions.each do |question|
          question.csv_header_names.each do |variable|
            array << variable
          end
        end
      end
    end
  end

  private

  def create_core_childs
    return if question_group_finish

    qg_finish = ::QuestionGroup::Finish.new(session_id: id)
    qg_finish.save!
    ::Question::Finish.create!(question_group_id: qg_finish.id)
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

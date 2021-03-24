# frozen_string_literal: true

class Session < ApplicationRecord
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :intervention, inverse_of: :sessions, touch: true

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

  enum schedule: { days_after: 'days_after', days_after_fill: 'days_after_fill', exact_date: 'exact_date', after_fill: 'after_fill' }, _prefix: :schedule

  delegate :published?, to: :intervention
  delegate :draft?, to: :intervention

  validates :name, presence: true
  validates :last_report_template_number, presence: true
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  after_commit :create_core_childs, on: :create

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

  def available_now
    return true if schedule == 'after_fill'
    return true if %w[days_after exact_date].include?(schedule) && schedule_at.noon.past?

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
end

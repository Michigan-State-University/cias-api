# frozen_string_literal: true

class Session < ApplicationRecord
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :intervention, inverse_of: :sessions, touch: true

  has_many :question_groups, dependent: :restrict_with_exception, inverse_of: :session
  has_many :question_group_plains, dependent: :restrict_with_exception, inverse_of: :session, class_name: 'QuestionGroup::Plain'
  has_one :question_group_default, dependent: :restrict_with_exception, inverse_of: :session, class_name: 'QuestionGroup::Default'
  has_one :question_group_finish, dependent: :restrict_with_exception, inverse_of: :session, class_name: 'QuestionGroup::Finish'
  has_many :questions, dependent: :restrict_with_exception, through: :question_groups
  has_many :answers, dependent: :restrict_with_exception, through: :questions
  has_many :invitations, as: :invitable, dependent: :destroy

  has_many :user_sessions, dependent: :restrict_with_exception, inverse_of: :session
  has_many :users, dependent: :restrict_with_exception, through: :user_sessions

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 0
  attribute :formula, :json, default: assign_default_values('formula')
  attribute :body, :json, default: assign_default_values('body')

  enum schedule: { days_after: 'days_after', days_after_fill: 'days_after_fill', exact_date: 'exact_date' }, _prefix: :schedule

  delegate :published?, to: :intervention

  validates :name, presence: true
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

  def propagate_settings
    return unless settings_changed?

    narrator = Hash[settings['narrator'].to_a - settings_was['narrator'].to_a]
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

  def add_user_sessions
    return if intervention.user_sessions.empty?

    UserSession.transaction do
      intervention.user_sessions.pluck(:user_id).each do |user_id|
        UserSession.create!(user_id: user_id, session_id: id)
      end
    end
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

  private

  def create_core_childs
    ::QuestionGroup::Default.create!(session_id: id) if question_group_default.nil?
    return unless question_group_finish.nil?

    qg_finish = ::QuestionGroup::Finish.new(session_id: id)
    qg_finish.save!
    ::Question::Finish.create!(question_group_id: qg_finish.id)
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/session'
  end
end

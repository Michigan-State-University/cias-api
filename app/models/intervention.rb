# frozen_string_literal: true

class Intervention < ApplicationRecord
  extend DefaultValues
  extend FriendlyId
  include AASM
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :problem, inverse_of: :interventions, touch: true

  has_many :question_groups, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :question_group_plains, dependent: :restrict_with_exception, inverse_of: :intervention, class_name: 'QuestionGroup::Plain'
  has_one :question_group_default, dependent: :restrict_with_exception, inverse_of: :intervention, class_name: 'QuestionGroup::Default'
  has_one :question_group_finish, dependent: :restrict_with_exception, inverse_of: :intervention, class_name: 'QuestionGroup::Finish'
  has_many :questions, dependent: :restrict_with_exception, through: :question_groups
  has_many :answers, dependent: :restrict_with_exception, through: :questions
  has_many :intervention_invitations, dependent: :restrict_with_exception, inverse_of: :intervention

  has_many :user_interventions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :users, dependent: :restrict_with_exception, through: :user_interventions

  friendly_id :name, use: :slugged

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 0
  attribute :formula, :json, default: assign_default_values('formula')
  attribute :body, :json, default: assign_default_values('body')

  enum schedule: { days_after: 'days_after', days_after_fill: 'days_after_fill', exact_date: 'exact_date' }, _prefix: :schedule

  delegate :published?, to: :problem

  validates :name, presence: true
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  after_commit :create_core_childs, on: :create

  def position_less_than
    @position_less_than ||= problem.interventions.where(position: ...position).order(:position)
  end

  def position_grather_than
    @position_grather_than ||= problem.interventions.where('position > ?', position).order(:position)
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

  def add_user_interventions
    return if problem.user_interventions.empty?

    bulk = []
    problem.user_interventions.pluck(:user_id).each do |user_id|
      h = {}
      h[:user_id] = user_id
      h[:intervention_id] = id
      timestamp = Time.current
      h[:created_at] = timestamp
      h[:updated_at] = timestamp
      bulk.push(h)
    end
    UserIntervention.insert_all(bulk)
  end

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  def perform_narrator_reflection(_placeholder)
    nil
  end

  def invite_by_email(emails)
    users_exists = ::User.where(email: emails)
    (emails - users_exists.pluck(:email)).each do |email|
      User.invite!(email: email)
    end

    bulk = []
    User.where(email: emails).find_each do |user|
      h = {}
      h[:intervention_id] = id
      h[:email] = user.email
      timestamp = Time.current
      h[:created_at] = timestamp
      h[:updated_at] = timestamp
      bulk.push(h)
    end
    InterventionInvitation.insert_all(bulk)
    InterventionJob::Invitation.perform_later(id, emails)
  end

  private

  def create_core_childs
    if question_group_default.nil?
      ::QuestionGroup::Default.create!(intervention_id: id)
    end
    if question_group_finish.nil?
      qg_finish = ::QuestionGroup::Finish.new(intervention_id: id)
      qg_finish.save!
      ::Question::Finish.create!(question_group_id: qg_finish.id)
    end
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end
end

# frozen_string_literal: true

class Question < ApplicationRecord
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :intervention, inverse_of: :questions
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :question

  attribute :narrator, :json, default: assign_default_values('narrator')
  attribute :position, :integer, default: 0
  attribute :formula, :json, default: { payload: '', patterns: [] }
  attribute :body, :json, default: { data: [] }

  has_one_attached :image
  has_many_attached :speeches

  has_one :image_attachment, -> { where(name: 'image') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :image_blob, through: :image_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  validates :title, :type, presence: true
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :narrator, json: { schema: -> { Rails.root.join("#{json_schema_path}/narrator.json").to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :body, presence: true, json: { schema: -> { Rails.root.join("db/schema/#{self.class.name.underscore}/body.json").to_s }, message: ->(err) { err } }

  def subclass_name
    self.class.to_s.demodulize
  end

  def questions_position_up_to_equal
    intervention.questions.where('questions.position >= ?', position).order(:position)
  end

  def another_or_feedback(next_obj, answers_var_values)
    return next_obj unless next_obj.is_a?(::Question::Feedback)

    next_obj.apply_formula(answers_var_values)
    next_obj
  end

  def next_intervention_or_question(answers_var_values)
    return nil if id.eql?(questions_position_up_to_equal.last.id)

    if formula['payload'].present?
      obj_src = exploit_formula(answers_var_values)

      if obj_src.is_a?(Hash)
        next_obj = obj_src['type'].safe_constantize.find(obj_src['id'])
        return another_or_feedback(next_obj, answers_var_values)
      end
    end
    next_obj = questions_position_up_to_equal[1]
    another_or_feedback(next_obj, answers_var_values)
  end

  def harvest_body_variables
    [nil]
  end

  def variable_clone_prefix
    nil
  end

  def execute_narrator
    Narrator.new(self).execute
  end

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/question'
  end
end

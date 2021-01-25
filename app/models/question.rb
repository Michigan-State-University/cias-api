# frozen_string_literal: true

class Question < ApplicationRecord
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface
  include BlockHelper

  belongs_to :question_group, inverse_of: :questions, touch: true, counter_cache: true
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :question

  attribute :narrator, :json, default: assign_default_values('narrator')
  attribute :position, :integer, default: 0
  attribute :formula, :json, default: assign_default_values('formula')
  attribute :body, :json, default: assign_default_values('body')

  has_one_attached :image
  has_many_attached :speeches

  has_one :image_attachment, -> { where(name: 'image') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :image_blob, through: :image_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  validates :title, :type, presence: true
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :narrator, json: { schema: -> { Rails.root.join("#{json_schema_path}/narrator.json").to_s }, message: ->(err) { err } }
  validates :video_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :body, presence: true, json: { schema: -> { Rails.root.join("db/schema/#{self.class.name.underscore}/body.json").to_s }, message: ->(err) { err } }

  delegate :session, to: :question_group
  after_create :initialize_narrator
  default_scope { order(:position) }

  def subclass_name
    self.class.to_s.demodulize
  end

  def position_equal_or_higher
    questionnaire = session.question_groups.includes([:questions]).map(&:questions).flatten
    current_position = questionnaire.map(&:id).find_index id
    @position_equal_or_higher ||= questionnaire.drop(current_position)
  end

  def another_or_feedback(next_obj, answers_var_values)
    return next_obj unless next_obj.is_a?(::Question::Feedback)

    next_obj.apply_formula(answers_var_values)
    next_obj
  end

  def perform_narrator_reflection(answers_var_values)
    narrator['blocks']&.each_with_index do |block, index|
      next unless block['type'].eql?('ReflectionFormula')

      narrator['blocks'][index]['target_value'] = exploit_formula(answers_var_values, block['payload'], block['reflections'])
      break
    end
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

  def initialize_narrator
    narrator['blocks'] << default_finish_screen_block if type == 'Question::Finish'
    execute_narrator
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/question'
  end
end

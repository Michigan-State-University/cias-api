# frozen_string_literal: true

class Question < ApplicationRecord
  include BodyInterface
  extend DefaultValues
  belongs_to :intervention, inverse_of: :questions
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :question

  attribute :narrator, :json, default: assign_default_values('narrator')
  attribute :position, :integer, default: 0

  has_one_attached :image

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

  def questions_same_intervention
    @questions_same_intervention ||= intervention.questions
  end

  def questions_position_up_to_equal
    questions_same_intervention.where('questions.position <= ?', position).order(:position)
  end

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/question'
  end
end

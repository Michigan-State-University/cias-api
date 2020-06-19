# frozen_string_literal: true

class Question < ApplicationRecord
  include BodyInterface
  include FormulaInterface
  include DefaultAttributes
  belongs_to :intervention, inverse_of: :questions
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :question

  before_validation -> { assign_default_attributes(:settings, :narrator) }, if: :new_record?

  has_one_attached :image

  has_one :image_attachment, -> { where(name: 'image') }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :image_blob, through: :image_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  validates :title, :type, presence: true
  validates :settings, json: { schema: -> { Rails.root.join('db/schema/question/settings.json').to_s }, message: ->(err) { err } }
  validates :narrator, json: { schema: -> { Rails.root.join('db/schema/question/narrator.json').to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join('db/schema/question/formula.json').to_s }, message: ->(err) { err } }
  validates :body, presence: true, json: { schema: -> { Rails.root.join("db/schema/#{self.class.name.underscore}/body.json").to_s }, message: ->(err) { err } }

  def subclass_name
    self.class.to_s.demodulize
  end
end

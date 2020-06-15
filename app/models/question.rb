# frozen_string_literal: true

class Question < ApplicationRecord
  include BodyInterface
  include FormulaInterface
  belongs_to :intervention
  has_many :answers, dependent: :restrict_with_exception

  has_one_attached :image

  validates :title, :type, presence: true
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("db/schema/#{self.class.name.underscore}/formula.json").to_s }, message: ->(err) { err } }
  validates :body, presence: true, json: { schema: -> { Rails.root.join("db/schema/#{self.class.name.underscore}/body.json").to_s }, message: ->(err) { err } }

  def subclass_name
    self.class.to_s.demodulize
  end
end

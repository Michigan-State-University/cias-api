# frozen_string_literal: true

class Question < ApplicationRecord
  include BodyInterface
  include FormulaInterface
  belongs_to :intervention
  has_many :answers, dependent: :restrict_with_exception

  has_one_attached :image

  validates :title, :type, presence: true

  def subclass_name
    self.class.to_s.demodulize
  end
end

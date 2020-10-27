# frozen_string_literal: true

class QuestionGroup < ApplicationRecord
  extend DefaultValues
  include ::Clone

  has_many :questions, dependent: :destroy, inverse_of: :question_group, class_name: 'Question'
  belongs_to :intervention, inverse_of: :question_groups, touch: true
  validates :title, :position, presence: true
end

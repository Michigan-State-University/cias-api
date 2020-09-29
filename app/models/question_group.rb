# frozen_string_literal: true

class QuestionGroup < ApplicationRecord
  extend DefaultValues
  include ::Clone

  belongs_to :intervention, inverse_of: :question_groups, touch: true
  has_many :questions, dependent: :destroy, inverse_of: :question_group

  attribute :title, :string, default: assign_default_values('title')
  attribute :position, :integer, default: assign_default_values('position')
  attribute :default, :boolean, default: assign_default_values('default')

  validates :title, :position, presence: true
end

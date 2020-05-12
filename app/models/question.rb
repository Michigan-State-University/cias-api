# frozen_string_literal: true

class Question < ApplicationRecord
  has_one :next, class_name: 'Question', foreign_key: 'previous_id', dependent: :restrict_with_exception
  belongs_to :previous, class_name: 'Question', optional: true

  belongs_to :intervention

  validates :title, :type, presence: true
end

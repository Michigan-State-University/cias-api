# frozen_string_literal: true

class Question < ApplicationRecord
  include BodyInterface
  has_one :next, class_name: 'Question', foreign_key: 'previous_id', dependent: :restrict_with_exception
  belongs_to :previous, class_name: 'Question', optional: true
  belongs_to :intervention
  has_many :answers, dependent: :restrict_with_exception

  validates :title, :type, presence: true

  def subclass_name
    self.class.to_s.demodulize
  end
end

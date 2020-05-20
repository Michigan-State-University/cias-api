# frozen_string_literal: true

class Intervention < ApplicationRecord
  include BodyInterface
  belongs_to :user
  has_many :questions, dependent: :restrict_with_exception
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  validates :type, :name, presence: true
end

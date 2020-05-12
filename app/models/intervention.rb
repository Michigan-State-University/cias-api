# frozen_string_literal: true

class Intervention < ApplicationRecord
  belongs_to :user
  has_many :questions, dependent: :restrict_with_exception

  validates :type, :name, presence: true
end

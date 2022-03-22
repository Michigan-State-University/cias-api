# frozen_string_literal: true

class Tlfb::Day < ApplicationRecord
  belongs_to :user_session
  belongs_to :question_group
  has_many :events, class_name: 'Tlfb::Event', dependent: :destroy
  has_one :consumption_result, class_name: 'Tlfb::ConsumptionResult', dependent: :destroy
  delegate :month, to: :exact_date
  delegate :year, to: :exact_date
  validates :exact_date, presence: true

  default_scope { order(exact_date: :desc) }

  def value
    exact_date.day
  end
end

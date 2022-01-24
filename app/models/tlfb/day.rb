# frozen_string_literal: true

class Tlfb::Day < ApplicationRecord
  belongs_to :user_session
  belongs_to :question_group
  delegate :month, to: :exact_date
  delegate :year, to: :exact_date
  validates :exact_date, presence: true

  def value
    exact_date.day
  end
end

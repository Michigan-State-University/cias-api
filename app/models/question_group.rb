# frozen_string_literal: true

class QuestionGroup < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include FormulaInterface
  include ::Clone

  CURRENT_VERSION = '1'

  has_many :questions, dependent: :destroy, inverse_of: :question_group, class_name: 'Question'
  has_many :tlfb_days, class_name: 'Tlfb::Day', dependent: :destroy
  belongs_to :session, inverse_of: :question_groups, touch: true, class_name: 'Session'
  attribute :position, :integer, default: 1
  validates :title, :position, presence: true
  default_scope { order(:position) }

  delegate :ability_to_update_for?, to: :session

  attribute :sms_schedule, :jsonb
  attribute :formulas, :jsonb, default: []
  validates :sms_schedule,
            json: { schema: -> { Rails.root.join('db/schema/_common/sms_schedule.json').to_s },
                    message: ->(err) { err } }, if: -> { session&.type&.match?('Session::Sms') },
            allow_blank: true

  after_initialize :set_default_values

  def set_default_values
    if session.type === 'Session::Sms'
      self.sms_schedule = {
        "day_of_period": [],
        "questions_per_day": 1
      }
    else
      self.sms_schedule = {}
    end
  end

  def finish?
    type == 'QuestionGroup::Finish'
  end
end

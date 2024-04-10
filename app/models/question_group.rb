# frozen_string_literal: true

class QuestionGroup < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include ::Clone

  CURRENT_VERSION = '1'

  has_many :questions, dependent: :destroy, inverse_of: :question_group, class_name: 'Question'
  has_many :tlfb_days, class_name: 'Tlfb::Day', dependent: :destroy
  belongs_to :session, inverse_of: :question_groups, touch: true, class_name: 'Session'
  attribute :position, :integer, default: 1
  validates :title, :position, presence: true
  default_scope { order(:position) }

  delegate :ability_to_update_for?, to: :session

  attribute :sms_schedule, :jsonb, default: {}
  validates :sms_schedule,
            json: { schema: lambda { Rails.root.join('db/schema/_common/sms_schedule.json').to_s },
                    message: lambda { |err|  err } }, if: -> { session&.type === 'Session::Sms' },
            allow_blank: true

  def finish?
    type == 'QuestionGroup::Finish'
  end
end

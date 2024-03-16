# frozen_string_literal: true

class QuestionGroup < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include ::Clone

  CURRENT_VERSION = '1'

  has_many :questions, dependent: :destroy, inverse_of: :question_group, class_name: 'Question'
  has_many :tlfb_days, class_name: 'Tlfb::Day', dependent: :destroy
  belongs_to :session, inverse_of: :question_groups, touch: true
  attribute :position, :integer, default: 1
  validates :title, :position, presence: true
  default_scope { order(:position) }

  delegate :ability_to_update_for?, to: :session

  def finish?
    type == 'QuestionGroup::Classic::Finish'
  end

  scope :classic_type, -> () { where(type: %w[QuestionGroup::Classic::Plain QuestionGroup::Classic::Finish]) }

  scope :sms_type, -> () { where(type: %w[QuestionGroup::Sms::Plain QuestionGroup::Sms::Finish]) }
end

# frozen_string_literal: true

class QuestionGroup::Initial < QuestionGroup
  has_one :question_initial, inverse_of: :question_group, class_name: '::Question::SmsInformation',
                             foreign_key: :question_group_id, dependent: :destroy

  attribute :title, :string, default: -> { I18n.t('question_group.initial.title') }
  attribute :position, :integer, default: 0
  validates :sms_schedule,
            json: { schema: -> { File.read(Rails.root.join('db/schema/_common/initial_sms_schedule.json').to_s) },
                    message: ->(err) { err } }, if: -> { session&.type&.match?('Session::Sms') },
            allow_blank: true

  attr_readonly :position
end

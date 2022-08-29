# frozen_string_literal: true

class Tlfb::ConsumptionResult < ApplicationRecord
  belongs_to :day, class_name: 'Tlfb::Day'

  delegate :user_session, to: :day
  delegate :question_group, to: :day

  attribute :body, :json, default: {}
  validates :body, json: {
    schema: -> { Rails.root.join("#{json_schema_path}/body.json").to_s },
    message: ->(err) { err }
  }

  private

  def json_schema_path
    'db/schema/tlfb/consumption_result'
  end
end

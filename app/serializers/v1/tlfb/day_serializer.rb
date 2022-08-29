# frozen_string_literal: true

class V1::Tlfb::DaySerializer < V1Serializer
  attributes :id

  attribute :date do |object|
    object.exact_date.strftime('%d-%m-%Y')
  end

  has_many :events, serializer: V1::Tlfb::EventSerializer
  has_one :consumption_result, serializer: V1::Tlfb::ConsumptionResultSerializer
end

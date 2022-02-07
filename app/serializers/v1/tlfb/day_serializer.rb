# frozen_string_literal: true

class V1::Tlfb::DaySerializer < V1Serializer
  attributes :id

  attribute :date do |object|
    object.exact_date.strftime('%d-%m-%Y')
  end

  has_many :events, serializer: V1::Tlfb::EventSerializer
  has_many :substances, serializer: V1::Tlfb::SubstanceSerializer
end

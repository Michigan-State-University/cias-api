# frozen_string_literal: true

class V1::PhoneSerializer < V1Serializer
  attributes :number, :iso, :prefix
end

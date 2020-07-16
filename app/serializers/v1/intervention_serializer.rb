# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  attributes :type, :settings, :status, :name, :slug, :body
end

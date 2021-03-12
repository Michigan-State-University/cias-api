# frozen_string_literal: true

class V1::SmsPlan::VariantSerializer < V1Serializer
  attributes :formula_match, :content
end

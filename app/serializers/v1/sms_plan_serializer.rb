# frozen_string_literal: true

class V1::SmsPlanSerializer < V1Serializer
  attributes :session_id, :name, :schedule, :schedule_payload, :frequency, :end_at, :formula,
             :no_formula_text, :is_used_formula
  has_many :variants, serializer: V1::SmsPlan::VariantSerializer
end

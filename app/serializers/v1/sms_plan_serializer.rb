# frozen_string_literal: true

class V1::SmsPlanSerializer < V1Serializer
  attributes :session_id, :name, :schedule, :schedule_payload, :frequency, :formula,
             :no_formula_text, :is_used_formula, :original_text
  has_many :variants, serializer: V1::SmsPlan::VariantSerializer

  attribute :end_at do |object|
    object.end_at.strftime('%d/%m/%Y') if object.end_at.present?
  end
end

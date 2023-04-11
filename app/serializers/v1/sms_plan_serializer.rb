# frozen_string_literal: true

class V1::SmsPlanSerializer < V1Serializer
  attributes :session_id, :name, :schedule, :schedule_payload, :frequency, :formula,
             :no_formula_text, :is_used_formula, :original_text, :type, :include_first_name, :include_last_name,
             :include_email, :include_phone_number
  has_many :variants, serializer: V1::SmsPlan::VariantSerializer
  has_many :phones, serializer: V1::PhoneSerializer

  attribute :end_at do |object|
    object.end_at.strftime('%d/%m/%Y') if object.end_at.present?
  end

  attribute :no_formula_image_url do |object|
    url_for(object.no_formula_image) if object.no_formula_image.attached?
  end
end

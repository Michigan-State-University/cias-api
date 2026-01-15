# frozen_string_literal: true

class V1::Export::SmsPlanSerializer < ActiveModel::Serializer
  attributes  :name, :schedule, :schedule_payload, :frequency, :end_at, :formula, :no_formula_text, :is_used_formula,
              :original_text, :type, :include_first_name, :include_last_name, :include_phone_number, :include_email,
              :schedule_variable, :sms_send_time_type, :sms_send_time_details

  has_many :variants, serializer: V1::Export::SmsPlanVariantSerializer

  attribute :version do
    SmsPlan::CURRENT_VERSION
  end
end

# frozen_string_literal: true

class V1::Export::SmsPlanVariantSerializer < ActiveModel::Serializer
  attributes :formula_match, :content, :original_text, :position

  has_many :sms_links, serializer: V1::Export::SmsLinkSerializer

  attribute :version do
    SmsPlan::Variant::CURRENT_VERSION
  end
end

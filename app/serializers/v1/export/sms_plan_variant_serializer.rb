# frozen_string_literal: true

class V1::Export::SmsPlanVariantSerializer < ActiveModel::Serializer
  attributes :formula_match, :content, :original_text, :position

  attribute :version do
    SmsPlan::Variant::CURRENT_VERSION
  end
end

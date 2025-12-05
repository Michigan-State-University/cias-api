# frozen_string_literal: true

class V1::Export::TagSerializer < ActiveModel::Serializer
  attributes :name

  attribute :version do
    Tag::CURRENT_VERSION
  end
end

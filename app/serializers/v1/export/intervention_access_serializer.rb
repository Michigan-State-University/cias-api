# frozen_string_literal: true

class V1::Export::InterventionAccessSerializer < ActiveModel::Serializer
  attributes :email

  attribute :version do
    InterventionAccess::CURRENT_VERSION
  end
end

# frozen_string_literal: true

class V1::Export::SmsLinkSerializer < ActiveModel::Serializer
  attributes :url, :link_type, :variable
end

# frozen_string_literal: true

module ExportHelper
  extend ActiveSupport::Concern

  def object_location(object, relation_name = nil, relation_position = nil)
    location_hash = {
      id: object.id,
      object_position: object.position
    }
    location_hash[relation_name] = relation_position if relation_position.present?
    location_hash
  end
end

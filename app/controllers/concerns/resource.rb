# frozen_string_literal: true

module Resource
  private

  def serialized_response(collection, from_model = controller_name.classify)
    "V1::#{from_model}Serializer".safe_constantize.
      new(collection).serialized_json
  end
end

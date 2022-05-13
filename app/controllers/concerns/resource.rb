# frozen_string_literal: true

module Resource
  private

  def model_constant
    @model_constant ||= controller_name.classify.demodulize.safe_constantize
  end

  def serialized_response(collection, from_model = controller_name.classify, params = {})
    "V1::#{from_model}Serializer".safe_constantize.
     new(collection, params: params).serializable_hash.to_json
  end

  def serialized_hash(collection, from_model = controller_name.classify, params = {})
    "V1::#{from_model}Serializer".safe_constantize.
      new(collection, params).serializable_hash
  end
end

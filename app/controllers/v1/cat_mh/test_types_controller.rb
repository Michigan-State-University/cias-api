# frozen_string_literal: true

class V1::CatMh::TestTypesController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: test_types_response
  end

  private

  def test_types_response
    V1::CatMh::TestTypeSerializer.new(CatMhTestType.all).serializable_hash.to_json
  end
end

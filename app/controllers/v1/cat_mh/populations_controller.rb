# frozen_string_literal: true

class V1::CatMh::PopulationsController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: populations_response
  end

  private

  def populations_response
    V1::CatMh::PopulationSerializer.new(CatMhPopulation.all).serializable_hash.to_json
  end
end

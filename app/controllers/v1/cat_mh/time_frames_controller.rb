# frozen_string_literal: true

class V1::CatMh::TimeFramesController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: time_frame_response
  end

  private

  def time_frame_response
    V1::CatMh::TimeFrameSerializer.new(CatMhTimeFrame.all).serializable_hash.to_json
  end
end

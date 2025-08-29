# frozen_string_literal: true

class V1::PingsController < V1Controller
  def show
    render json: { message: 'pong' }, status: :ok
  end
end

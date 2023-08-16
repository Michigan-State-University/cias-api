# frozen_string_literal: true

class V1::EpicOnFhir::JwkSetsController < V1Controller
  skip_before_action :authenticate_user!

  def index
    render json: Api::EpicOnFhir::JwkSetsService.call
  end
end

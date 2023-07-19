# frozen_string_literal: true

class V1::HenryFord::ClinicLocationsController < V1Controller
  def index
    authorize! :read, Intervention

    render json: serialized_hash(ClinicLocation.all.order(:name))
  end
end

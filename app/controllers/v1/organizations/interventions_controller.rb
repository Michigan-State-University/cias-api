# frozen_string_literal: true

class V1::Organizations::InterventionsController < V1Controller
  def index
    authorize! :read, Intervention

    collection = interventions_scope
    paginated_collection = paginate(collection, params)

    render json: serialized_hash(paginated_collection).merge({ interventions_size: collection.size }).to_json
  end

  private

  def interventions_scope
    Intervention.with_any_organization.accessible_by(current_ability).where(organization_id: params[:organization_id])
  end
end

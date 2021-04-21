# frozen_string_literal: true

class V1::OrganizationsController < V1Controller
  def index
    authorize! :read, Organization

    render json: serialized_response(organization_scope)
  end

  def show
    authorize! :read, Organization

    render json: serialized_response(organization_load)
  end

  def create
    authorize! :create, Organization

    organization = V1::Organizations::Create.call(organization_params)
    render json: serialized_response(organization), status: :created
  end

  def update
    authorize! :update, Organization

    organization = V1::Organizations::Update.call(organization_load, organization_params)
    render json: serialized_response(organization)
  end

  def destroy
    authorize! :delete, Organization
    V1::Organizations::Destroy.call(organization_load)
    head :no_content
  end

  private

  def organization_scope
    Organization.accessible_by(current_ability)
  end

  def organization_load
    organization_scope.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :organization_admins_to_add, :organization_admins_to_remove)
  end
end

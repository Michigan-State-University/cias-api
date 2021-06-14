# frozen_string_literal: true

class V1::OrganizationsController < V1Controller
  def index
    authorize! :read, Organization

    if current_v1_user.roles.include?('health_clinic_admin')
      render json: simple_response(organization_scope)
    else
      render json: organizations_response(organization_scope)
    end
  end

  def show
    authorize! :read, Organization

    render json: organization_response(organization_load)
  end

  def create
    authorize! :create, Organization

    organization = V1::Organizations::Create.call(organization_params)
    render json: serialized_response(organization), status: :created
  end

  def update
    authorize! :update, Organization

    organization = V1::Organizations::Update.call(organization_load, organization_params)
    render json: organization_response(organization)
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
    params.require(:organization).permit(:name, organization_admins_to_add: [], organization_admins_to_remove: [])
  end

  def simple_response(organization)
    V1::SimpleOrganizationSerializer.new(organization)
  end

  def organization_response(organization)
    V1::OrganizationSerializer.new(
      organization,
      { include: %i[health_systems health_clinics e_intervention_admins organization_admins] }
    )
  end

  def organizations_response(organizations)
    V1::OrganizationSerializer.new(
      organizations,
      { include: %i[health_systems health_clinics] }
    )
  end
end

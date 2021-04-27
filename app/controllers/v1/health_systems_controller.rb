# frozen_string_literal: true

class V1::HealthSystemsController < V1Controller
  def index
    authorize! :read, HealthSystem

    render json: serialized_response(health_system_scope)
  end

  def show
    authorize! :read, HealthSystem

    render json: serialized_response(health_system_load)
  end

  def create
    authorize! :create, HealthSystem

    health_system = V1::HealthSystems::Create.call(health_system_params)
    render json: serialized_response(health_system), status: :created
  end

  def update
    authorize! :update, HealthSystem

    health_system = V1::HealthSystems::Update.call(health_system_load, health_system_params)
    render json: serialized_response(health_system)
  end

  def destroy
    authorize! :delete, HealthSystem
    V1::HealthSystems::Destroy.call(health_system_load)
    head :no_content
  end

  private

  def health_system_scope
    HealthSystem.accessible_by(current_ability)
  end

  def health_system_load
    health_system_scope.find(params[:id])
  end

  def health_system_params
    params.require(:health_system).permit(:name, :organization_id, :health_system_admins_to_add, :health_system_admins_to_remove)
  end
end

# frozen_string_literal: true

class V1::HealthClinicsController < V1Controller
  def index
    authorize! :read, HealthClinic

    health_clinics = clinic_scope
    health_clinics = health_clinics.joins(:health_system).where(health_systems: { organization_id: filter_params }) unless filter_params.nil?
    render json: serialized_response(health_clinics)
  end

  def show
    authorize! :read, HealthClinic

    render json: health_clinic_response(clinic_load)
  end

  def create
    authorize! :create, HealthClinic

    clinic = V1::HealthClinics::Create.call(clinic_params)
    render json: serialized_response(clinic), status: :created
  end

  def update
    authorize! :update, HealthClinic

    return head :forbidden if clinic_load.deleted?

    health_clinic = V1::HealthClinics::Update.call(clinic_load, clinic_params)

    render json: serialized_response(health_clinic)
  end

  def destroy
    authorize! :delete, HealthClinic

    V1::HealthClinics::Destroy.call(clinic_load)
    head :no_content
  end

  private

  def clinic_scope
    return HealthClinic.accessible_by(current_ability).with_deleted if with_deleted?

    HealthClinic.accessible_by(current_ability)
  end

  def clinic_load
    clinic_scope.find(params[:id])
  end

  def clinic_params
    params.require(:health_clinic).permit(:name, :health_system_id)
  end

  def with_deleted?
    to_boolean(params[:with_deleted])
  end

  def filter_params
    params[:organization_id]
  end

  def to_boolean(value)
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  def health_clinic_response(health_clinic)
    V1::HealthClinicSerializer.new(
      health_clinic,
      { include: %i[health_clinic_admins] }
    )
  end
end

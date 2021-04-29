class V1::HealthClinicController <V1Controller
  def index
    authorize! :read, HealthClinic

    render json: serialized_response(clinic_scope)
  end

  def show
    authroize! :read, HealthClinic

    render json: serialized_response(clinic_load)
  end

  def create
    authorize! :create, HealthClinic

    clinic = V1::HealthClinic::Create.call(clinic_params)
    render json: serialized_response(clinic), status: :created
  end

  def update
    authorize! :update, HealthClinic

    health_clinic = V1::HealthClinic::Update.call(clinic_load, clinic_params)
    render json: serialized_response(health_clinic)
  end

  def destroy
    authorize! :delete, HealthClinic

    V1::HealthClinic::Destroy.call(clinic_load)
    head :no_content
  end

  private

  def clinic_scope
    HealthClinic.accesible_by(current_ability)
  end

  def clinic_load
    clinic_scope.find(params[:id])
  end

  def clinic_params
    params.require(:clinic).permit(:name)
  end
end

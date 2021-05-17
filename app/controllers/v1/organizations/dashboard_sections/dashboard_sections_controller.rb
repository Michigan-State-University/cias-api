# frozen_string_literal: true

class V1::Organizations::DashboardSections::DashboardSectionsController < V1Controller
  load_and_authorize_resource :organization

  def index
    authorize! :read, DashboardSection

    render json: dashboard_section_response(dashboard_section_scope)
  end

  def show
    authorize! :read, DashboardSection

    render json: dashboard_section_response(dashboard_section_load)
  end

  def create
    authorize! :create, DashboardSection

    dashboard_section = V1::Organizations::DashboardSections::Create.call(@organization, dashboard_section_params)
    render json: serialized_response(dashboard_section), status: :created
  end

  def update
    authorize! :update, DashboardSection

    dashboard_section = V1::Organizations::DashboardSections::Update.call(dashboard_section_load, dashboard_section_params)
    render json: serialized_response(dashboard_section)
  end

  def destroy
    authorize! :delete, DashboardSection

    V1::Organizations::DashboardSections::Destroy.call(dashboard_section_load)
    head :no_content
  end

  private

  def dashboard_section_scope
    @dashboard_section_scope ||= @organization.reporting_dashboard.dashboard_sections
  end

  def dashboard_section_load
    @dashboard_section_load ||= dashboard_section_scope.find(params[:id])
  end

  def dashboard_section_params
    params.require(:dashboard_section).permit(:name, :description)
  end

  def dashboard_section_response(response)
    V1::DashboardSectionSerializer.new(
      response,
      { include: %i[charts] }
    )
  end
end

# frozen_string_literal: true

class V1::Organizations::DashboardSections::DashboardSectionsController < V1Controller
  load_and_authorize_resource :organization
  include Resource::Position

  def index
    authorize! :read, DashboardSection

    sections = dashboard_sections_scope

    sections = sections.joins(:charts).where(charts: { status: :published }) if filter_status
    render json: dashboard_section_response(sections)
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

    dashboard_section = V1::Organizations::DashboardSections::Update.call(dashboard_section_load,
                                                                          dashboard_section_params)
    render json: serialized_response(dashboard_section)
  end

  def destroy
    authorize! :delete, DashboardSection

    V1::Organizations::DashboardSections::Destroy.call(dashboard_section_load)
    head :no_content
  end

  private

  def dashboard_sections_scope
    @dashboard_sections_scope ||= @organization.reporting_dashboard.dashboard_sections
  end

  def dashboard_section_load
    @dashboard_section_load ||= dashboard_sections_scope.find(params[:id])
  end

  def dashboard_section_params
    params.expect(dashboard_section: %i[name description])
  end

  def filter_status
    params[:published]
  end

  def dashboard_section_response(response)
    V1::DashboardSectionSerializer.new(
      response,
      { include: %i[charts], params: { only_published: filter_status } }
    )
  end
end

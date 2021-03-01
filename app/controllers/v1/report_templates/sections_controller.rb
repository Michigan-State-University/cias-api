# frozen_string_literal: true

class V1::ReportTemplates::SectionsController < V1Controller
  load_and_authorize_resource :report_template

  def index
    authorize! :read, ReportTemplate::Section

    render json: serialized_section_response(sections_scope)
  end

  def show
    authorize! :read, section

    render json: serialized_section_response(section)
  end

  def create
    new_section = ReportTemplate::Section.new(report_template_id: @report_template.id)

    authorize! :create, new_section

    new_section.formula = section_params[:formula]
    new_section.save!

    render json: serialized_section_response(new_section), status: :created
  end

  def update
    authorize! :update, section

    section.update!(formula: section_params[:formula])

    render json: V1::ReportTemplate::SectionSerializer.new(
      section.reload,
      { include: %i[variants] }
    )
  end

  def destroy
    authorize! :destroy, section

    section.destroy!
    head :no_content
  end

  private

  def serialized_section_response(sections)
    serialized_response(sections, 'ReportTemplate::Section')
  end

  def section
    @section ||= sections_scope.find(params[:id])
  end

  def sections_scope
    @sections_scope ||= @report_template.sections
  end

  def section_params
    params.require(:section).permit(:formula)
  end
end

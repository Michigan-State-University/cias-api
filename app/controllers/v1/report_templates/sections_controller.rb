# frozen_string_literal: true

class V1::ReportTemplates::SectionsController < V1Controller
  include Reorder

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
    return head :forbidden unless @report_template.ability_to_update_for?(current_v1_user)

    new_section = ReportTemplate::Section.new(report_template_id: @report_template.id)

    authorize! :create, new_section

    new_section.formula = section_params[:formula]
    new_section.save!

    render json: serialized_section_response(new_section), status: :created
  end

  def update
    authorize! :update, section

    return head :forbidden unless @report_template.ability_to_update_for?(current_v1_user)

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

  protected

  def reorder_data_scope
    sections_scope
  end

  def reorder_response
    V1::ReportTemplateSerializer.new(
      @report_template,
      { include: %i[sections variants] }
    )
  end

  private

  def serialized_section_response(sections)
    serialized_response(sections, 'ReportTemplate::Section')
  end

  def section
    @section ||= sections_scope.find(params[:id])
  end

  def sections_scope
    @sections_scope ||= @report_template.sections.includes(variants: [image_blob: :attachments, image_attachment: :blob])
  end

  def section_params
    params.expect(section: [:formula])
  end

  def position_params
    params.expect(section: [position: %i[id position]])
  end

  def ability_to_update?
    @report_template.ability_to_update_for?(current_v1_user)
  end
end

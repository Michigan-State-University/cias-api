# frozen_string_literal: true

class V1::ReportTemplates::Sections::VariantsController < V1Controller
  load_and_authorize_resource :report_template_section, class: 'ReportTemplate::Section',
                                                        id_param: :section_id

  def index
    authorize! :read, ReportTemplate::Section::Variant

    render json: serialized_variant_response(variants_scope)
  end

  def show
    authorize! :read, variant

    render json: serialized_variant_response(variant)
  end

  def create
    return head :forbidden unless @report_template_section.ability_to_update_for?(current_v1_user)

    new_variant = ReportTemplate::Section::Variant.
      new(report_template_section_id: @report_template_section.id)

    authorize! :create, new_variant

    new_variant.assign_attributes(variant_params)
    new_variant.save!

    render json: serialized_variant_response(new_variant), status: :created
  end

  def update
    authorize! :update, variant

    return head :forbidden unless @report_template_section.ability_to_update_for?(current_v1_user)

    V1::ReportTemplates::Variants::Update.call(
      variant,
      variant_params
    )

    render json: serialized_variant_response(variant.reload)
  end

  def destroy
    authorize! :destroy, variant
    return head :forbidden unless @report_template_section.ability_to_update_for?(current_v1_user)

    variant.destroy!

    head :no_content
  end

  def remove_image
    authorize! :remove_logo, variant
    return head :forbidden unless @report_template_section.ability_to_update_for?(current_v1_user)

    variant.image.purge

    render status: :ok
  end

  private

  def serialized_variant_response(variants)
    serialized_response(variants, 'ReportTemplate::Section::Variant')
  end

  def variant
    @variant ||= variants_scope.find(params[:id] || params[:variant_id])
  end

  def variants_scope
    @variants_scope ||= @report_template_section.variants
  end

  def variant_params
    params.require(:variant).permit(:preview, :formula_match, :title, :content, :image)
  end
end

# frozen_string_literal: true

class V1::Interventions::TransfersController < V1Controller
  def import
    authorize! :create, Intervention

    file = intervention_import_params[:file]
    return render status: :bad_request unless correct_format?(file)

    Interventions::ImportJob.perform_later(current_v1_user.id, JSON.parse(file).deep_transform_keys(&:to_sym))
    render status: :created
  end

  def export
    authorize! :update, Intervention

    Interventions::ExportJob.perform_later(current_v1_user.id, intervention_export_params)

    render status: :ok
  end

  private

  def intervention_import_params
    params.require(:imported_file).permit(:file)
  end

  def intervention_export_params
    params.require(:id)
  end

  def correct_format?(file)
    file.content_type == 'application/json'
  end
end

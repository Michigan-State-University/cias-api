# frozen_string_literal: true

class V1::Interventions::TransfersController < V1Controller
  def import
    authorize! :create, Intervention
    return render status: :bad_request unless correct_format?(file)

    import_file = ImportedFile.create!(file: file)
    Interventions::ImportJob.perform_later(current_v1_user.id, import_file.id)
    render status: :created
  end

  def export
    authorize! :update, Intervention

    Interventions::ExportJob.perform_later(current_v1_user.id, intervention_export_params)

    render status: :ok
  end

  private

  def intervention_import_params
    params.expect(imported_file: [:file])
  end

  def intervention_export_params
    params.require(:id)
  end

  def correct_format?(file)
    file.content_type == 'application/json'
  end

  def file
    @file ||= intervention_import_params[:file]
  end
end

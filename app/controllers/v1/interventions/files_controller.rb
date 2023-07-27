# frozen_string_literal: true

class V1::Interventions::FilesController < V1Controller
  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return render status: :method_not_allowed unless intervention_load.can_have_files?
    return render status: :payload_too_large if file_sizes_too_big?

    V1::Intervention::AttachFiles.call(intervention_load, files)
    render json: serialized_response(intervention_load, 'Intervention'), status: :created
  end

  def destroy
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return render status: :method_not_allowed unless intervention_load.can_have_files?

    @file = ActiveStorage::Attachment.find(file_id)
    @file.purge_later
    # this line is needed to notify cache that the record has changed (attaching files raises update callbacks, purging them does not)
    intervention_load.touch # rubocop:disable Rails/SkipsModelValidations

    render json: serialized_response(intervention_load, 'Intervention')
  end

  private

  def file_sizes_too_big?
    files.any? { |file| file.size > 10.megabytes }
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def intervention_params
    params.require(:intervention).permit(files: [])
  end

  def files
    intervention_params[:files]
  end

  def file_id
    params[:id]
  end

  def intervention_published?
    intervention_load.published?
  end
end

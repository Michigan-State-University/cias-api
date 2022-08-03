# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSetups::FilesController < V1Controller
  def create
    authorize! :update, Intervention

    return render status: :payload_too_large if participant_files_too_big?

    setup = setup_load
    participant_files.each { |file| setup.participant_files.attach(file) }
    render json: serialized_response(setup.reload, 'LiveChat::Interventions::NavigatorSetup')
  end

  def destroy
    authorize! :update, Intervention

    ActiveStorage::Attachment.accessible_by(current_ability).find(participant_file_id)&.purge_later
    head :no_content
  end

  private

  def participant_files
    file_params[:participant_files] || []
  end

  def participant_file_id
    params[:participant_file_id]
  end

  def file_params
    params.require(:navigator_setup).permit(participant_files: [])
  end

  def setup_load
    Intervention.accessible_by(current_ability).find(params[:id]).navigator_setup
  end

  def participant_files_too_big?
    participant_files.any? { |file| file.size > 5.megabytes }
  end
end

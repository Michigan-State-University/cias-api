# frozen_string_literal: true

class V1::LiveChat::Interventions::FilesController < V1Controller
  def create
    authorize! :update, Intervention

    return render status: :payload_too_large if files_too_big?

    assign_file_to_setup!
    render json: serialized_response(setup_load.reload, 'LiveChat::Interventions::NavigatorSetup')
  end

  def destroy
    authorize! :update, Intervention

    ActiveStorage::Attachment.accessible_by(current_ability).find(file_id)&.purge_later
    head :no_content
  end

  private

  def files
    file_params[:files] || []
  end

  def files_for
    file_params[:files_for]
  end

  def file_id
    params[:file_id]
  end

  def file_params
    params.require(:navigator_setup).permit(:files_for, files: [])
  end

  def setup_load
    @setup_load ||= Intervention.accessible_by(current_ability).find(params[:id]).navigator_setup
  end

  def files_too_big?
    files.any? { |file| file.size > 5.megabytes }
  end

  def assign_file_to_setup!
    files_collection = setup_load.public_send("#{files_for.singularize}_files")
    files.each { |file| files_collection&.attach(file) }
  end
end

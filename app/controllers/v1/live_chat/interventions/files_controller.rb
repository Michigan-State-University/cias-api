# frozen_string_literal: true

class V1::LiveChat::Interventions::FilesController < V1Controller
  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load

    return render status: :payload_too_large if files_too_big?

    assign_file_to_setup!
    render json: serialized_response(setup_load.reload, 'LiveChat::Interventions::NavigatorSetup')
  end

  def destroy
    authorize! :update, Intervention
    authorize! :update, intervention_load

    selected_files(params[:files_for]).find(file_id).purge_later

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

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(params[:id])
  end

  def setup_load
    @setup_load ||= intervention_load.navigator_setup
  end

  def files_too_big?
    files.any? { |file| file.size > 5.megabytes }
  end

  def assign_file_to_setup!
    files_collection = selected_files(files_for)
    files.each { |file| files_collection&.attach(file) }
  end

  def selected_files(files_for)
    setup_load.public_send("#{files_for.singularize}_files")
  end
end

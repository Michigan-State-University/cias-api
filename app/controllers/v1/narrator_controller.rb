# frozen_string_literal: true

class V1::NarratorController < V1Controller
  def create
    authorize! :update, model.safe_constantize

    MultipleCharacters::ChangeNarratorJob.perform_later(model, object_id, new_narrator, replaced_animation)

    head :ok
  end

  private

  def model
    params[:_model]
  end

  def object_id
    params[:id]
  end

  def narrator_params
    params.require(:narrator).permit(:name, replaced_animations: {})
  end

  def new_narrator
    narrator_params[:name]
  end

  def replaced_animation
    narrator_params[:replaced_animations]
  end
end

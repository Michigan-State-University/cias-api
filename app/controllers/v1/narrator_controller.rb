# frozen_string_literal: true

class V1::NarratorController < V1Controller
  around_action :with_locale, only: :create

  def create
    authorize! :update, object_load

    MultipleCharacters::ChangeNarratorJob.perform_later(current_v1_user, model, object_id, new_narrator, replaced_animation)

    head :ok
  end

  private

  def model
    params[:_model]
  end

  def object_id
    params[:id]
  end

  def object_load
    model.safe_constantize.find(object_id)
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

  def locale
    object_load.language_code
  end
end

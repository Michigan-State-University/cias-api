# frozen_string_literal: true

class V1::Tlfb::SubstancesController < V1Controller
  def create
    authorize! :create, Tlfb::Substance

    substance = Tlfb::Substance.create!(substance_create_params)
    render json: serialized_response(substance, Tlfb::Substance)
  end

  def update
    authorize! :update, Tlfb::Substance

    substance = substance_load
    substance.update!(substance_update_params)
    render json: serialized_response(substance.reload, Tlfb::Substance)
  end

  private

  def substance_params
    params.require(:substance).permit(:user_session_id, :question_group_id, :exact_date, body: {})
  end

  def substance_create_params
    params.require(:substance).permit(body: {}).merge({ day: day_for_substance })
  end

  def substance_update_params
    params.require(:substance).permit(body: {})
  end

  def substance_id
    params[:id]
  end

  def substance_load
    Tlfb::Substance.find(substance_id)
  end

  def user_session_id
    substance_params[:user_session_id]
  end

  def question_group_id
    substance_params[:question_group_id]
  end

  def day_for_substance
    Tlfb::Day.find_or_create_by!(
      question_group_id: question_group_id,
      user_session_id: user_session_id,
      exact_date: substance_params[:exact_date]
    )
  end
end

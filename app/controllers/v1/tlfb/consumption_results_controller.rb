# frozen_string_literal: true

class V1::Tlfb::ConsumptionResultsController < V1Controller
  def create
    authorize! :create, Tlfb::ConsumptionResult

    consumption_result = Tlfb::ConsumptionResult.create!(consumption_result_create_params)
    render json: serialized_response(consumption_result, Tlfb::ConsumptionResult)
  end

  def update
    authorize! :update, Tlfb::ConsumptionResult

    consumption_result = consumption_result_load
    consumption_result.update!(consumption_result_update_params)
    render json: serialized_response(consumption_result.reload, Tlfb::ConsumptionResult)
  end

  private

  def consumption_result_params
    params.expect(consumption_result: [:user_session_id, :question_group_id, :exact_date, { body: {} }])
  end

  def consumption_result_create_params
    params.expect(consumption_result: [body: {}]).merge({ day: day_for_substance })
  end

  def consumption_result_update_params
    params.expect(consumption_result: [body: {}])
  end

  def consumption_result_id
    params[:id]
  end

  def consumption_result_load
    Tlfb::ConsumptionResult.find(consumption_result_id)
  end

  def user_session_id
    consumption_result_params[:user_session_id]
  end

  def question_group_id
    consumption_result_params[:question_group_id]
  end

  def day_for_substance
    Tlfb::Day.find_or_create_by!(
      question_group_id: question_group_id,
      user_session_id: user_session_id,
      exact_date: consumption_result_params[:exact_date]
    )
  end
end

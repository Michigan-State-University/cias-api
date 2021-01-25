# frozen_string_literal: true

class V1::Sessions::FlowsController < V1Controller
  def index
    question = V1::FlowService.new(current_v1_user, params[:answer_id]).answer_branching_flow
    render json: serialized_response(
      question,
      question&.de_constantize_modulize_name || NilClass
    )
  end

  private

  def index_params
    params.require(:answer_id)
  end
end

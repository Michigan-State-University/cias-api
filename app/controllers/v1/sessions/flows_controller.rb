# frozen_string_literal: true

class V1::Sessions::FlowsController < V1Controller
  def index
    question_with_warning = V1::FlowService.new(current_v1_user, params[:answer_id]).answer_branching_flow
    response = serialized_hash(
      question_with_warning[:question],
      question_with_warning[:question]&.de_constantize_modulize_name || NilClass
    )
    if question_with_warning[:warning].presence && question_with_warning[:question].session.intervention.draft?
      response = response.merge(warning: question_with_warning[:warning])
    end
    render json: response
  end

  private

  def index_params
    params.require(:answer_id)
  end
end

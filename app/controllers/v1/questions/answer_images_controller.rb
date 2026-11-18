# frozen_string_literal: true

class V1::Questions::AnswerImagesController < V1Controller
  def create
    authorize! :update, Question

    result = V1::Question::AnswerImage::Create.call(question_load, answer_id, question_params[:file])

    render json: serialized_response(result, 'Question'), status: :created
  end

  def update
    authorize! :update, Question

    result = V1::Question::AnswerImage::Update.call(question_load, params[:answer_id], question_params[:image_alt])

    render json: serialized_response(result, 'Question')
  end

  def destroy
    authorize! :update, Question

    result = V1::Question::AnswerImage::Destroy.call(question_load, params[:answer_id])

    render json: serialized_response(result, 'Question')
  end

  private

  def question_load
    Question.accessible_by(current_ability).find(params[:question_id])
  end

  def answer_id
    params.expect(image: [:answer_id])[:answer_id]
  end

  def question_params
    params.expect(image: %i[file image_alt answer_id])
  end
end

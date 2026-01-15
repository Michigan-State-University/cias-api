# frozen_string_literal: true

class V1::Questions::ImagesController < V1Controller
  def create
    authorize! :update, Question

    question_load.update!(image: question_params[:file])
    invalidate_cache(question_load)
    render json: serialized_response(question_load, 'Question'), status: :created
  end

  def update
    authorize! :update, Question

    question_load.image_blob&.update!(description: question_params[:image_alt])
    render json: serialized_response(question_load, 'Question')
  end

  def destroy
    authorize! :destroy, Question

    question_load.image.purge
    invalidate_cache(question_load)
    render json: serialized_response(question_load, 'Question')
  end

  private

  def question_load
    Question.accessible_by(current_ability).find(params[:question_id])
  end

  def question_params
    params.expect(image: %i[file image_alt])
  end
end

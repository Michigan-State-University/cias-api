# frozen_string_literal: true

class V1::Questions::ImagesController < V1Controller
  def create
    question_load.update!(image: question_params[:file])
    invalidate_cache(question_load)
    render json: serialized_response(question_load, 'Question'), status: 201
  end

  def destroy
    question_load.image.purge
    invalidate_cache(question_load)
    render json: serialized_response(question_load, 'Question')
  end

  private

  def question_load
    Question.accessible_by(current_ability).find(params[:question_id])
  end

  def question_params
    params.require(:image).permit(:file)
  end
end

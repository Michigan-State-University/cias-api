# frozen_string_literal: true

class V1::Tlfb::EventsController < V1Controller
  def create
    authorize! :create, Tlfb::Event

    event = V1::Tlfb::Event::Create.call(exact_date, user_session_id, question_group_id)

    render json: serialized_response(event, Tlfb::Event), status: :created
  end

  def update
    authorize! :update, Tlfb::Event

    event_load.update!(update_params)

    render json: serialized_response(event_load.reload, Tlfb::Event)
  end

  def destroy
    authorize! :destroy, Tlfb::Event

    event_load.destroy!
    head :no_content
  end

  private

  def event_load
    Tlfb::Event.accessible_by(current_ability).find(event_id)
  end

  def event_id
    params[:id]
  end

  def event_params
    params.expect(event: %i[name exact_date user_session_id question_group_id])
  end

  def exact_date
    event_params[:exact_date]
  end

  def user_session_id
    event_params[:user_session_id]
  end

  def question_group_id
    event_params[:question_group_id]
  end

  def update_params
    params.required(:event).permit(:name)
  end
end

# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone
  include Resource::Position

  authorize_resource only: %i[create update]

  def index
    render json: serialized_response(interventions_scope)
  end

  def show
    render json: serialized_response(intervention_load)
  end

  def create
    intervention = interventions_scope.new(intervention_params)
    intervention.position = interventions_scope.last&.position.to_i + 1
    intervention.save!
    render json: serialized_response(intervention), status: :created
  end

  def update
    intervention = intervention_load
    intervention.assign_attributes(intervention_params)
    intervention.integral_update
    render json: serialized_response(intervention)
  end

  def invite
    authorize! :update, intervention_load

    emails = (invite_params[:emails] + intervention_load.emails.dup).uniq
    InvitationJob::Participant::Intervention.perform_later(invite_params[:emails], intervention_load.id)
    intervention_load.update(emails: emails)
    render json: serialized_response(intervention_load)
  end

  private

  def interventions_scope
    Problem.includes(:interventions).accessible_by(current_ability).find(params[:problem_id]).interventions.order(:position)
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def invite_params
    params.require(:intervention).permit(emails: [])
  end

  def intervention_params
    params.require(:intervention).permit(:name, :schedule, :schedule_at, :position, :problem_id, narrator: {}, settings: {}, formula: {}, body: {})
  end
end

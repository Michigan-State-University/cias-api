# frozen_string_literal: true

module Resource::Position
  extend ActiveSupport::Concern

  def position
    authorize! :update, model_constant

    scope = position_scope
    return head :forbidden unless ability_to_update?

    validate_positions!(position_params[:position])
    V1::Positions::Update.call(scope, position_params[:position])
    render json: serialized_response(response_scope["#{controller_name.classify.underscore}s"])
  end

  private

  # Authorizes the parent record and returns the records the caller may reorder.
  def position_scope
    raise NotImplementedError, "Including class did not implement #{__method__} method"
  end

  def ability_to_update?
    true
  end

  def validate_positions!(_values); end

  def position_params
    params.expect(controller_name.classify.underscore.to_sym => [position: [%i[id position]]])
  end

  def response_scope
    { controller_name.to_s => send(:"#{controller_name}_scope") }
  end
end

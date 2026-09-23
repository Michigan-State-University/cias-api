# frozen_string_literal: true

# Unauthenticated so an anonymous guest can check a test link before any fill exists; inspecting is read-only and spends nothing.
class V1::TestRuns::LinkTokensController < V1Controller
  skip_before_action :authenticate_user!, only: %i[verify]

  # No wrapping: it would copy the token under `link_token`, where `erase_from_params` cannot reach it.
  wrap_parameters false

  def verify
    inspection = V1::TestRuns::LinkToken.inspect_token(verify_params[:test_link_token])

    render json: {
      status: inspection.status,
      valid: inspection.valid?,
      intervention_id: inspection.intervention_id
    }, status: :ok
  end

  private

  # Do not rename: `filter_parameters` and `erase_from_params` redact `test_link_token` by key, a rename leaks the credential.
  def verify_params
    params.permit(:test_link_token)
  end
end

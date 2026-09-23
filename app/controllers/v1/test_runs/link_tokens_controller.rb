# frozen_string_literal: true

# Lets the landing page ask, before it creates anything, whether the test link it was opened with is
# still alive.
#
# It exists because the fill path fails open on purpose: a dead token silently produces an ordinary
# participant fill, and phase 4's manual purge was dropped, so that fill is permanent study data
# nobody can remove. Telling the researcher after the session exists is too late — this is the check
# that lets the client refuse to start one.
#
# Unauthenticated, because the person opening a test link is an anonymous guest who has no token of
# their own yet. The surface is kept to the minimum that makes that safe:
#
# * It is read-only *in the domain*. Nothing is spent, counted or marked; a token can be inspected
#   any number of times and is exactly as usable afterwards. This is not an endpoint that can be
#   used to burn somebody else's link. It is not write-free in the database, though:
#   `ApplicationController` includes `Log`, so every call writes one `user_log_requests` row plus
#   its `versions` copy, with `params` scrubbed by `Log::UserRequest#erase_from_params`.
# * It answers only about a token the caller already holds, and adds nothing the holder could not
#   already get by using it. The `intervention_id` it echoes is the one the caller pasted into their
#   own address bar moments earlier.
# * The *response* carries no `minted_by_id` — who minted a link is staff attribution, not something
#   an anonymous caller gets to learn. The token is signed, not encrypted, so a holder can already
#   read that payload; this endpoint adds nothing. It reveals nothing about the intervention itself
#   either: no name, no status, not even whether that id exists. The intervention is never loaded.
# * It is not an oracle for guessing tokens: every answer is a plain 200, forging a signature needs
#   `secret_key_base`, and `ApplicationController`'s `rate_limit` bounds the request rate.
class V1::TestRuns::LinkTokensController < V1Controller
  skip_before_action :authenticate_user!, only: %i[verify]

  def verify
    inspection = V1::TestRuns::LinkToken.inspect_token(verify_params[:test_link_token])

    render json: {
      status: inspection.status,
      valid: inspection.valid?,
      intervention_id: inspection.intervention_id
    }, status: :ok
  end

  private

  # The parameter has to keep this exact name: `config.filter_parameters` and
  # `Log::UserRequest#erase_from_params` both redact `test_link_token` by key, so renaming it here
  # would put a live credential into the request logs in clear text.
  def verify_params
    params.permit(:test_link_token)
  end
end

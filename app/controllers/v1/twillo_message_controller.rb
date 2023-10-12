# frozen_string_literal: true

class V1::TwilloMessageController < V1Controller
  skip_before_action :authenticate_user!

  def create
    p '-------------RECEIVED BODY------------'
    p transform_keys
    p '-------------END RECEIVED BODY------------'
    response = V1::Sms::Replay.call(transform_keys)
    render xml: response
  end

  private

  def transform_keys
    @transform_keys ||= params.deep_transform_keys(&:underscore)
  end
end

# frozen_string_literal: true

class V1::TwilloMessageController < V1Controller
  skip_before_action :authenticate_user!

  def create
    p '-------------MESSAGE------------'
    p params
    p '-------------MESSAGE-END------------'
    response = V1::Sms::Replay.call(params)
    p '-----------__RESPONSE-------------'
    p response
    p '==============RESPONSE-END_--------------'
    render xml: response
  end

  private

  def transform_keys
    @transform_keys ||= params.deep_transform_keys(&:underscore)
  end
end

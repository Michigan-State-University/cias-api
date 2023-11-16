# frozen_string_literal: true

class V1::TwilloMessageController < V1Controller
  skip_before_action :authenticate_user!

  def create
    response = V1::Sms::Replay.call(from, to, body)
    render xml: response
  end

  private

  def transformed_params
    @transformed_params ||= params.deep_transform_keys(&:underscore)
  end

  def from
    transformed_params[:from]
  end

  def to
    transformed_params[:to]
  end

  def body
    transformed_params[:body]
  end
end

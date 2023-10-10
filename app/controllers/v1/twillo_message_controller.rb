# frozen_string_literal: true

class V1::TwilloMessageController < V1Controller
  skip_before_action :authenticate_user!

  def create
    p '==============PARAMS START=============='
    p params
    p '==============PARAMS END=============='
  end

  private

  def from
    params[:from]
  end

  def to
    params[:to]
  end

  def body
    params[:body]
  end
end

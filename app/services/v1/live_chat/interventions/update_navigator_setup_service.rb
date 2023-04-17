# frozen_string_literal: true

class V1::LiveChat::Interventions::UpdateNavigatorSetupService
  def self.call(setup, params)
    new(setup, params).call
  end

  def initialize(setup, params)
    @setup = setup
    @params = params
  end

  def call
    params[:phone_attributes] = { id: setup.phone.id, _destroy: true } if !setup.phone.nil? && params[:phone_attributes].nil?
    if !setup.message_phone.nil? && params[:message_phone_attributes].nil?
      params[:message_phone_attributes] = { id: setup.message_phone.id,
                                            _destroy: true }
    end
    setup.update!(params)
  end

  attr_reader :setup, :params
end

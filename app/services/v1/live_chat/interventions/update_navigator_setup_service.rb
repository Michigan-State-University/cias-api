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
    if setup.phone.nil?
      setup.update!(params.merge({ phone: new_phone }))
    else
      setup.update!(params.except(:phone))
      if params.key?(:phone)
        if params[:phone].nil?
          setup.phone.destroy!
          setup.phone = nil
          setup.save!
        else
          setup.phone.update!(params[:phone])
        end
      end
    end
  end

  attr_reader :setup, :params

  private

  def new_phone
    Phone.create!(params[:phone]) if params[:phone].present?
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::ConfirmationsController, type: :routing do
  describe 'routing' do
    it 'routes to #new' do
      expect(get: '/v1/auth/confirmation/new').to route_to('v1/auth_controller/confirmations#new')
    end

    it 'routes to #show' do
      expect(get: '/v1/auth/confirmation').to route_to('v1/auth_controller/confirmations#show')
    end

    it 'routes to #create' do
      expect(post: '/v1/auth/confirmation').to route_to('v1/auth_controller/confirmations#create')
    end
  end
end

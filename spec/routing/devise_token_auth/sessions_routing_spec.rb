# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::SessionsController, type: :routing do
  describe 'routing' do
    it 'routes to #create' do
      expect(post: '/v1/auth/sign_in').to route_to('v1/auth/sessions#create')
    end

    it 'routes to #destroy' do
      expect(delete: '/v1/auth/sign_out').to route_to('v1/auth/sessions#destroy')
    end
  end
end

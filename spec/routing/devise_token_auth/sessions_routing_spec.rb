# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::SessionsController, type: :routing do
  describe 'routing' do
    it 'routes to #create' do
      expect(post: '/auth/sign_in').to route_to('devise_token_auth/sessions#create')
    end

    it 'routes to #destroy' do
      expect(delete: '/auth/sign_out').to route_to('devise_token_auth/sessions#destroy')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::ConfirmationsController, type: :routing do
  describe 'routing' do
    it 'routes to #new' do
      expect(get: '/auth/confirmation/new').to route_to('devise_token_auth/confirmations#new')
    end

    it 'routes to #show' do
      expect(get: '/auth/confirmation').to route_to('devise_token_auth/confirmations#show')
    end

    it 'routes to #create' do
      expect(post: '/auth/confirmation').to route_to('devise_token_auth/confirmations#create')
    end
  end
end

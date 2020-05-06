# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::PasswordsController, type: :routing do
  describe 'routing' do
    it 'routes to #new' do
      expect(get: '/auth/password/new').to route_to('devise_token_auth/passwords#new')
    end

    it 'routes to #edit' do
      expect(get: '/auth/password/edit').to route_to('devise_token_auth/passwords#edit')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/auth/password').to route_to('devise_token_auth/passwords#update')
    end

    it 'routes to #update via PUT' do
      expect(put: '/auth/password').to route_to('devise_token_auth/passwords#update')
    end

    it 'routes to #create' do
      expect(post: '/auth/password').to route_to('devise_token_auth/passwords#create')
    end
  end
end

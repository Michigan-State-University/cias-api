# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::RegistrationsController, type: :routing do
  describe 'routing' do
    it 'routes to #cancel' do
      expect(get: '/v1/auth/cancel').to route_to('devise_token_auth/registrations#cancel')
    end

    it 'routes to #new' do
      expect(get: '/v1/auth/sign_up').to route_to('devise_token_auth/registrations#new')
    end

    it 'routes to #edit' do
      expect(get: '/v1/auth/edit').to route_to('devise_token_auth/registrations#edit')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/v1/auth').to route_to('devise_token_auth/registrations#update')
    end

    it 'routes to #update via PUT' do
      expect(put: '/v1/auth').to route_to('devise_token_auth/registrations#update')
    end

    it 'routes to #destroy' do
      expect(delete: '/v1/auth').to route_to('devise_token_auth/registrations#destroy')
    end

    it 'routes to #create' do
      expect(post: '/v1/auth').to route_to('devise_token_auth/registrations#create')
    end
  end
end

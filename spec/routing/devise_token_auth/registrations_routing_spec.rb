# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::RegistrationsController, type: :routing do
  describe 'routing' do
    it 'routes to #cancel' do
      expect(get: '/auth/cancel').to route_to('devise_token_auth/registrations#cancel')
    end

    it 'routes to #new' do
      expect(get: '/auth/sign_up').to route_to('devise_token_auth/registrations#new')
    end

    it 'routes to #edit' do
      expect(get: '/auth/edit').to route_to('devise_token_auth/registrations#edit')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/auth').to route_to('devise_token_auth/registrations#update')
    end

    it 'routes to #update via PUT' do
      expect(put: '/auth').to route_to('devise_token_auth/registrations#update')
    end

    it 'routes to #destroy' do
      expect(delete: '/auth').to route_to('devise_token_auth/registrations#destroy')
    end

    it 'routes to #create' do
      expect(post: '/auth').to route_to('devise_token_auth/registrations#create')
    end
  end
end

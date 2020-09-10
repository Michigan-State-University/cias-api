# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviseTokenAuth::PasswordsController, type: :routing do
  describe 'routing' do
    it 'routes to #new' do
      expect(get: '/v1/auth/password/new').to route_to('v1/auth_controller/passwords#new')
    end

    it 'routes to #edit' do
      expect(get: '/v1/auth/password/edit').to route_to('v1/auth_controller/passwords#edit')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/v1/auth/password').to route_to('v1/auth_controller/passwords#update')
    end

    it 'routes to #update via PUT' do
      expect(put: '/v1/auth/password').to route_to('v1/auth_controller/passwords#update')
    end

    it 'routes to #create' do
      expect(post: '/v1/auth/password').to route_to('v1/auth_controller/passwords#create')
    end
  end
end

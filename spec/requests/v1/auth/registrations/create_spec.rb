# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/auth', type: :request do
  let(:params) do
    {
      email: 'test@test.com',
      password: 'password',
      password_confirmation: 'password',
      first_name: 'first name',
      last_name: 'last name',
      terms: true,
      time_zone: 'Europe/Warsaw',
      confirm_success_url: 'https://cias-web.herokuapp.com/login'
    }
  end

  let(:request) { post '/v1/auth', params: params }

  context 'when params are valid' do
    it 'return correct status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'add new user' do
      expect { request }.to change(User, :count).by(1)
    end

    it 'fill data' do
      request
      expect(User.find_by(email: 'test@test.com').terms).to eq(true)
    end
  end

  context 'user didn\'t accept t&c' do
    let(:params) do
      {
        email: 'test@test.com',
        password: 'password',
        password_confirmation: 'password',
        first_name: 'first name',
        last_name: 'last name',
        terms: false,
        time_zone: 'Europe/Warsaw',
        confirm_success_url: 'https://cias-web.herokuapp.com/login'
      }
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'have correct message' do
      request
      expect(json_response['message']).to eq('Terms must be accepted')
    end

    it 'did\'t add a new user' do
      expect { request }.to avoid_changing { User.count }
    end
  end

  context 'user provided blank first and last_name' do
    let(:params) do
      {
        email: 'test@test.com',
        password: 'password',
        password_confirmation: 'password',
        first_name: '',
        last_name: '',
        terms: true,
        time_zone: 'Europe/Warsaw',
        confirm_success_url: 'https://cias-web.herokuapp.com/login'
      }
    end

    before do
      request
    end

    it 'return correct status' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'have correct message' do
      expect(json_response['message']).to include('First name cannot be blank')
    end

    it 'did\'t add a new user' do
      expect { request }.to avoid_changing { User.count }
    end

    context 'after param change' do
      let(:params) do
        {
          email: 'test@test.com',
          password: 'password',
          password_confirmation: 'password',
          first_name: 'first name',
          last_name: '',
          terms: true,
          time_zone: 'Europe/Warsaw',
          confirm_success_url: 'https://cias-web.herokuapp.com/login'
        }
      end

      it 'have correct message after change in params' do
        request
        expect(json_response['message']).to include('Last name cannot be blank')
      end
    end
  end
end

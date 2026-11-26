# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/auth', type: :request do
  let(:web_url) { 'https://web.example.test' }
  let(:confirm_success_url) { "#{web_url}/login" }
  let(:params) do
    {
      email: 'test@test.com',
      password: 'password123!',
      password_confirmation: 'password123!',
      first_name: 'first name',
      last_name: 'last name',
      terms: true,
      time_zone: 'Europe/Warsaw',
      confirm_success_url: confirm_success_url
    }
  end

  let(:request) { post '/v1/auth', params: params }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

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
      expect(User.find_by(email: 'test@test.com').terms).to be(true)
    end

    it 'enqueues confirmation instructions email with confirm_success_url' do
      expect { request }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
        .with(kind_of(User), kind_of(String), hash_including(redirect_url: confirm_success_url))
    end
  end

  shared_examples 'rejected confirm_success_url' do
    it 'returns unprocessable content with message' do
      request
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['message']).to eq I18n.t('users.redirect_url.not_allowed')
    end

    it 'does not create a user' do
      expect { request }.to avoid_changing { User.count }
    end

    it 'does not enqueue any email' do
      expect { request }.not_to have_enqueued_mail
    end
  end

  {
    'web app host as the user part' => 'https://web.example.test@other.example.test/login',
    'foreign subdomain starting with the web app host' => 'https://web.example.test.other.example.test/login',
    'another port' => 'https://web.example.test:8443/login',
    'another scheme' => 'http://web.example.test/login',
    'relative path' => '/login',
    'unparseable string' => 'not a url',
    'another host' => 'https://other.example.test/login'
  }.each do |description, url|
    context "when confirm_success_url has #{description}" do
      let(:confirm_success_url) { url }

      it_behaves_like 'rejected confirm_success_url'
    end
  end

  context 'when WEB_URL is not set' do
    before { stub_const('ENV', ENV.to_hash.except('WEB_URL')) }

    it_behaves_like 'rejected confirm_success_url'
  end

  context 'when confirm_success_url is rejected and the e-mail has a pending invitation' do
    let(:confirm_success_url) { 'https://other.example.test/login' }

    before { User.invite!(email: params[:email]) }

    it 'returns the redirect URL error before looking up the account' do
      request
      expect(json_response['message']).to eq I18n.t('users.redirect_url.not_allowed')
    end
  end

  context 'user didn\'t accept t&c' do
    let(:params) do
      {
        email: 'test@test.com',
        password: 'password123!',
        password_confirmation: 'password123!',
        first_name: 'first name',
        last_name: 'last name',
        terms: false,
        time_zone: 'Europe/Warsaw',
        confirm_success_url: confirm_success_url
      }
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:unprocessable_content)
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
        password: 'password123!',
        password_confirmation: 'password',
        first_name: '',
        last_name: '',
        terms: true,
        time_zone: 'Europe/Warsaw',
        confirm_success_url: confirm_success_url
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
          password: 'password123!',
          password_confirmation: 'password',
          first_name: 'first name',
          last_name: '',
          terms: true,
          time_zone: 'Europe/Warsaw',
          confirm_success_url: confirm_success_url
        }
      end

      it 'have correct message after change in params' do
        request
        expect(json_response['message']).to include('Last name cannot be blank')
      end
    end

    context 'when user has pending invitation and registers outside of invitation link' do
      let!(:invited_user) { User.invite!(email: 'mike.wazowski@gmail.com') }

      let!(:params) do
        password = Faker::Internet.password
        {
          email: invited_user.email,
          confirm_success_url: confirm_success_url,
          password: password,
          password_confirmation: password,
          terms: true,
          first_name: 'Mike',
          last_name: 'Wazowski'
        }
      end

      before { request }

      it 'returns correct status code' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns correct error message' do
        expect(json_response['message']).to eq I18n.t('activerecord.errors.models.user.not_using_invitation_link')
      end
    end
  end
end

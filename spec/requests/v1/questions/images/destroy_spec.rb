# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_information) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_question_images_path(question.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_question_images_path(question.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is appropriate Content-Type' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is success' do
      before { request }

      it { expect(response).to have_http_status(:ok) }
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_information) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { delete v1_question_images_path(question.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { delete v1_question_images_path(question.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is appropriate Content-Type' do
      before do
        delete v1_question_images_path(question.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is success' do
      before do
        delete v1_question_images_path(question.id), headers: headers
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end

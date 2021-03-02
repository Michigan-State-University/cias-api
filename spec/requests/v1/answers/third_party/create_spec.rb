# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:user_session) { create(:user_session, session: session, user: researcher) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_third_party, question_group: question_group) }
  let(:params) do
    {
      answer: {
        type: 'Answer::ThirdParty',
        body: {
          data: [
            {
              value: 'hospital_1_@test.org'
            }
          ]
        }
      },
      question_id: question.id
    }
  end

  before do
    post v1_user_session_answers_path(user_session.id), params: params, headers: researcher.create_new_auth_token
  end

  context 'when creating an answer' do
    it 'returns correct http status' do
      expect(response).to have_http_status(:created)
    end

    it 'returns correct question type' do
      expect(json_response['data']['attributes']['type']).to eq 'Answer::ThirdParty'
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_phone, question_group: question_group) }
  let(:params) do
    {
      answer: {
        type: 'Answer::Phone',
        body: {
          data: [
            {
              var: 'phone',
              value: '+48123123123'
            }
          ]
        }
      }
    }
  end

  before do
    post v1_question_answers_path(question.id), params: params, headers: user.create_new_auth_token
  end

  context 'when creating an answer' do
    %i[admin researcher participant guest].each do |role|
      let(:user) { create(:user, :confirmed, role) }

      context "when #{role} creates an answer" do
        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct question type' do
          expect(json_response['data']['attributes']['type']).to eq 'Answer::Phone'
        end

        it 'returns correct question id' do
          expect(json_response['data']['attributes']['question']['id']).to eq question.id
        end

        it 'creates user session ' do
          expect(UserSession.where(session_id: session.id, user_id: user.id).count).to eq 1
        end
      end

      context "when #{role} creates an answer with user session" do
        let(:user_session) { create(:user_session, user: user, session: session) }

        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct question type' do
          expect(json_response['data']['attributes']['type']).to eq 'Answer::Phone'
        end

        it 'returns correct question id' do
          expect(json_response['data']['attributes']['question']['id']).to eq question.id
        end

        it 'does not create user session' do
          expect(UserSession.where(session_id: session.id, user_id: user.id).count).to eq 1
        end
      end
    end
  end
end

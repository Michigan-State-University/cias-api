# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/user_sessions/:user_session_id/answers', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:user_session) { create(:user_session, session: session, user: user) }
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
      },
      question_id: question.id
    }
  end

  before do
    post v1_user_session_answers_path(user_session.id), params: params, headers: user.create_new_auth_token
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
      end
    end
  end
end

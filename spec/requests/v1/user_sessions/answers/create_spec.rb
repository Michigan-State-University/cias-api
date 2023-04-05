# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/user_sessions/:user_session_id/answers', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:user) { participant }
  let(:status) { 'draft' }
  let(:params) do
    {
      'answer' => {
        'type' => 'Answer::Single',
        'body' => {
          'data' => [
            {
              'var' => 'single_var',
              'value' => '1'
            }
          ]
        }
      },
      'question_id' => question_id
    }
  end

  let(:request) { post v1_user_session_answers_path(user_session.id), headers: user.create_new_auth_token, params: params }

  context 'UserSession::Classic' do
    let(:session) { create(:session, intervention_id: intervention.id) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:user_session) { create(:user_session, user: user, session: session) }
    let(:question_id) { question.id }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'return correct data' do
      request
      expect(json_response['data']).to include(
        'type' => 'answer',
        'attributes' => {
          'type' => 'Answer::Single',
          'decrypted_body' => {
            'data' => [
              {
                'var' => 'single_var',
                'value' => '1'
              }
            ]
          },
          'question_id' => question.id,
          'next_session_id' => nil
        }
      )
    end

    it 'create answer' do
      expect { request }.to change(Answer, :count).by(1)
    end

    context 'override existing answer' do
      let!(:answer) { create(:answer_single, user_session: user_session, question: question, draft: true, alternative_branch: true) }

      it 'update answer' do
        expect { request }.to change(Answer, :count).by(0)
      end

      it 'update a flags' do
        request
        expect(answer.reload.draft).to be(false)
        expect(answer.reload.alternative_branch).to be(false)
      end
    end
  end

  context 'UserSession::CatMh' do
    let(:session) { create(:cat_mh_session, :with_cat_mh_info, intervention: intervention) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: user) }
    let(:user_session) do
      UserSession.create(session: session, user: participant, type: 'UserSession::CatMh', last_answer_at: DateTime.current, user_intervention: user_int)
    end
    let(:question_id) { '1' }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'not add an answer to db' do
      expect { request }.to change(Answer, :count).by(0)
    end
  end
end

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

    it 'user intervention has correct status' do
      request
      expect(user_session.user_intervention.reload.status).to eql('in_progress')
    end

    context 'override existing answer' do
      let!(:answer) { create(:answer_single, user_session: user_session, question: question, draft: true, alternative_branch: true) }

      it 'update answer' do
        expect { request }.not_to change(Answer, :count)
      end

      it 'update a flags' do
        request
        expect(answer.reload.draft).to be(false)
        expect(answer.reload.alternative_branch).to be(false)
      end
    end

    context 'when autofinish is off and the question has "Fire report if get this far" on' do
      let(:question) { create(:question_single, :start_autofinish_timer_on, question_group: question_group) }

      it 'schedules the inactivity timeout' do
        expect { request }.to have_enqueued_job(UserSessionTimeoutJob).with(user_session.id, 'inactivity_timeout')
      end
    end

    it_behaves_like 'deactivated account'

    it_behaves_like 'paused intervention'
  end

  context 'when a published session is answered the way the answer screens send it' do
    let(:intervention) { create(:intervention, :published, user_id: researcher.id) }
    let(:session) { create(:session, intervention_id: intervention.id) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }
    let(:user_session) { create(:user_session, user: participant, session: session, user_intervention: user_int) }
    let(:question_id) { question.id }
    let(:answer_type) { 'Answer::Single' }
    let(:data) { AnswerBodySamples::ALL[answer_type][:data] }
    let(:params) { { answer: { type: answer_type, body: { data: data }, video_stats: {} }, question_id: question_id } }
    let(:request) do
      post v1_user_session_answers_path(user_session.id), headers: user.create_new_auth_token, params: params, as: :json
    end

    AnswerBodySamples::ALL.each do |type, sample|
      context "with #{type}" do
        let(:answer_type) { type }
        let(:question) { create(sample[:question], question_group: question_group) }

        it 'returns and stores the body exactly as sent, with the same JSON types' do
          request
          expect(response).to have_http_status(:created)
          expect(json_response['data']['attributes']).to include('type' => type, 'question_id' => question.id,
                                                                 'decrypted_body' => { 'data' => data })
          expect(response.body).not_to include('ciphertext')
          expect(Answer.find(json_response['data']['id']).decrypted_body).to eq('data' => data)
        end
      end
    end

    [nil, 'Answer::Single', [{ type: 'Answer::Single' }]].each do |answer|
      context "when answer is #{answer.inspect}" do
        let(:params) { { answer: answer, question_id: question_id } }

        it_behaves_like 'rejects malformed params', -> { Answer.count }
      end
    end

    context 'without question_id' do
      let(:params) { { answer: { type: answer_type, body: { data: data } } } }

      it_behaves_like 'rejects malformed params', -> { Answer.count }
    end

    context 'when the answer type does not match the question' do
      let(:params) { { answer: { type: 'Answer::Number', body: { data: [{ var: 'single_var', value: 1 }] } }, question_id: question_id } }

      it 'is rejected with 422' do
        request
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response).to include('message')
      end
    end

    context 'when the answer names another user session' do
      let(:params) do
        { answer: { type: 'Answer::Single', body: { data: data }, video_stats: {}, user_session_id: SecureRandom.uuid }, question_id: question_id }
      end

      it 'ignores it and stores the answer on the user session from the URL' do
        request
        expect(response).to have_http_status(:created)
        expect(Answer.find(json_response['data']['id']).user_session_id).to eq(user_session.id)
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
      expect { request }.not_to change(Answer, :count)
    end
  end
end

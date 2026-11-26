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

  shared_examples 'a rejected answer' do |status|
    it "returns #{status} and writes nothing" do
      user_session
      expect { request }.to avoid_changing { Answer.unscoped.order(:id).pluck(:id, :updated_at) }
        .and avoid_changing { user_session.reload.last_answer_at }
      expect(response).to have_http_status(status)
    end
  end

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

  context 'when the owner answers' do
    let(:intervention) { create(:intervention, :published, user_id: researcher.id) }
    let(:session) { create(:session, intervention: intervention) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:question_id) { question.id }
    let(:user_session) { create(:user_session, user: user, session: session) }

    %i[guest participant predefined_participant].each do |role|
      context "as a #{role}" do
        let(:user) { create(:user, :confirmed, role) }

        it 'saves the answer' do
          expect { request }.to change { user_session.answers.count }.by(1)
          expect(response).to have_http_status(:created)
        end
      end
    end

    context 'as a preview user' do
      let(:intervention) { create(:intervention, user_id: researcher.id) }
      let(:user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }

      it 'saves the answer' do
        expect { request }.to change { user_session.answers.count }.by(1)
        expect(response).to have_http_status(:created)
      end
    end
  end

  context 'when an admin answers a participant session' do
    let(:session) { create(:session, intervention: intervention) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:question_id) { question.id }
    let(:user_session) { create(:user_session, user: participant, session: session) }
    let(:user) { create(:user, :confirmed, :admin) }

    it 'saves the answer' do
      expect { request }.to change { user_session.answers.count }.by(1)
      expect(response).to have_http_status(:created)
    end
  end

  context 'when the caller does not own the user session' do
    let(:team) { create(:team) }
    let(:researcher) { create(:user, :confirmed, :researcher, team_id: team.id) }
    let(:intervention) { create(:intervention, :published, user_id: researcher.id) }
    let(:session) { create(:session, intervention: intervention, autofinish_enabled: true) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:question_id) { question.id }
    let(:owner) { participant }
    let(:finished_at) { nil }
    let(:user_session) do
      create(:user_session, user: owner, session: session, last_answer_at: 1.day.ago, finished_at: finished_at)
    end
    let(:user) { create(:user, :confirmed, :participant) }

    before { create(:answer_single, user_session: user_session, question: question, draft: true) }

    %i[guest participant predefined_participant].each do |role|
      context "and is a #{role}" do
        let(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'a rejected answer', :forbidden
      end
    end

    context 'and is the researcher who owns the intervention' do
      let(:user) { researcher }

      it_behaves_like 'a rejected answer', :forbidden
    end

    context 'and is a collaborator with data access to the intervention' do
      let(:user) { create(:user, :confirmed, :researcher) }

      before { create(:collaborator, user: user, intervention: intervention, data_access: true) }

      it_behaves_like 'a rejected answer', :forbidden
    end

    context "and is the team admin of the intervention owner's team" do
      let(:user) { team.team_admin }

      it_behaves_like 'a rejected answer', :forbidden
    end

    context 'and both are preview users of the same session' do
      let(:intervention) { create(:intervention, user_id: researcher.id) }
      let(:owner) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
      let(:user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }

      it_behaves_like 'a rejected answer', :forbidden
    end

    context 'and the intervention is paused' do
      let(:intervention) { create(:intervention, :paused, user_id: researcher.id) }

      it_behaves_like 'a rejected answer', :forbidden
    end

    context 'and the user session is finished' do
      let(:finished_at) { 1.hour.ago }

      it_behaves_like 'a rejected answer', :forbidden
    end
  end

  context 'when the question belongs to another session' do
    let(:session) { create(:session, intervention: intervention, autofinish_enabled: true) }
    let(:user_session) { create(:user_session, user: user, session: session, last_answer_at: 1.day.ago) }
    let(:foreign_question) { create(:question_single, question_group: create(:question_group, session: other_session)) }
    let(:question_id) { foreign_question.id }

    context 'of the same intervention' do
      let(:other_session) { create(:session, intervention: intervention) }

      it_behaves_like 'a rejected answer', :not_found
    end

    context 'of another intervention' do
      let(:other_session) { create(:session) }

      it_behaves_like 'a rejected answer', :not_found
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

    context 'when the caller does not own the user session' do
      let(:user) { create(:user, :confirmed, :participant) }
      let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }

      before { allow(Api::CatMh::Answer).to receive(:call).and_call_original }

      it_behaves_like 'a rejected answer', :forbidden

      it 'does not send the answer to CAT-MH' do
        request
        expect(Api::CatMh::Answer).not_to have_received(:call)
      end
    end
  end
end

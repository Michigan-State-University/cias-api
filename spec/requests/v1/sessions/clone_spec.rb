# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:session) { create(:session) }
  let!(:other_session) { create(:session) }
  let!(:question_group_1) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
  let!(:question_group_2) { create(:question_group, title: 'Question Group Title 2', session: session, position: 2) }
  let!(:question_1) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle', position: 1,
                             formula: { 'payload' => 'var + 3', 'patterns' => [
                               { 'match' => '=7', 'target' => { 'id' => question_2.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_2) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle 2', position: 2,
                             formula: { 'payload' => 'var + 4', 'patterns' => [
                               { 'match' => '=3', 'target' => { 'id' => other_session.id, type: 'Session' } }
                             ] })
  end
  let!(:question_3) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle 3', position: 3,
                             formula: { 'payload' => 'var + 2', 'patterns' => [
                               { 'match' => '=4', 'target' => { 'id' => question_4.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_4) do
    create(:question_single, question_group: question_group_2, subtitle: 'Question Subtitle 4', position: 1,
                             formula: { 'payload' => 'var + 7', 'patterns' => [
                               { 'match' => '=11', 'target' => { 'id' => question_1.id, type: 'Question::Single' } }
                             ] })
  end

  context 'when auth' do
    context 'is invalid' do
      before { post v1_clone_session_path(id: session.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_clone_session_path(id: session.id), headers: user.create_new_auth_token }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'not found' do
    let(:invalid_session_id) { '1' }

    before do
      post v1_clone_session_path(id: invalid_session_id), headers: user.create_new_auth_token
    end

    it 'has correct failure http status' do
      expect(response).to have_http_status(:not_found)
    end

    it 'has correct failure message' do
      expect(json_response['message']).to eq("Couldn't find Session with 'id'=#{invalid_session_id}")
    end
  end

  context 'when user clones a session' do
    before { post v1_clone_session_path(id: session.id), headers: user.create_new_auth_token }

    let(:cloned_session_id) { json_response['data']['id'] }
    let(:cloned_questions_collection) do
      Question.unscoped.includes(:question_group).where(question_groups: { session_id: cloned_session_id })
              .order('question_groups.position' => 'asc', 'questions.position' => 'asc')
    end
    let(:cloned_question_groups) { Session.find(cloned_session_id).question_groups.order(:position) }

    let(:session_was) do
      session.attributes.except('id', 'created_at', 'updated_at', 'position')
    end

    let(:session_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'position')
    end

    it 'has correct http code' do
      expect(response).to have_http_status(:created)
    end

    it 'origin and outcome same' do
      expect(session_was).to eq(session_cloned)
    end

    it 'has correct position' do
      expect(json_response['data']['attributes']['position']).to eq(2)
    end

    it 'has correct number of sessions' do
      expect(session.intervention.sessions.size).to eq(2)
    end

    it 'correctly clone questions' do
      expect(cloned_questions_collection.map(&:attributes)).to include(
        include(
          'subtitle' => 'Question Subtitle',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => '' }
          ),
          'formula' => {
            'payload' => 'var + 3',
            'patterns' => [
              { 'match' => '=7', 'target' => { 'id' => cloned_questions_collection.second.id, 'type' => 'Question::Single' } }
            ]
          }
        ),
        include(
          'subtitle' => 'Question Subtitle 2',
          'position' => 2,
          'body' => include(
            'variable' => { 'name' => '' }
          ),
          'formula' => {
            'payload' => 'var + 4',
            'patterns' => [
              { 'match' => '=3', 'target' => { 'id' => other_session.id, 'type' => 'Session' } }
            ]
          }
        ),
        include(
          'subtitle' => 'Question Subtitle 3',
          'position' => 3,
          'body' => include(
            'variable' => { 'name' => '' }
          ),
          'formula' => {
            'payload' => 'var + 2',
            'patterns' => [
              { 'match' => '=4', 'target' => { 'id' => cloned_questions_collection.fourth.id, 'type' => 'Question::Single' } }
            ]
          }
        ),
        include(
          'subtitle' => 'Question Subtitle 4',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => '' }
          ),
          'formula' => {
            'payload' => 'var + 7',
            'patterns' => [
              { 'match' => '=11', 'target' => { 'id' => cloned_questions_collection.first.id, 'type' => 'Question::Single' } }
            ]
          }
        ),
        include(
          'position' => 999_999,
          'type' => 'Question::Finish'
        )
      )
    end
  end
end

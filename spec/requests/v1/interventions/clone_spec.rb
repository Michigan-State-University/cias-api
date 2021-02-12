# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention, position: 1) }
  let!(:other_session) { create(:session, intervention: intervention, position: 2) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:question_1) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                             formula: { 'payload' => 'var + 3', 'patterns' => [
                               { 'match' => '=7', 'target' => { 'id' => question_2.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_2) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2,
                             formula: { 'payload' => 'var + 4', 'patterns' => [
                               { 'match' => '=3', 'target' => { 'id' => other_session.id, type: 'Session' } }
                             ] })
  end
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post clone_v1_intervention_path(id: intervention.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post clone_v1_intervention_path(id: intervention.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when user clones an intervention' do
    before { post clone_v1_intervention_path(id: intervention.id), headers: headers }

    let(:cloned_intervention_object) { Intervention.find(json_response['data']['id']) }
    let(:cloned_sessions) { cloned_intervention_object.sessions.order(:position) }
    let(:cloned_questions) { cloned_sessions.first.questions.order(:position) }

    let(:intervention_was) do
      intervention.attributes.except('id', 'created_at', 'updated_at')
    end

    let(:intervention_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'sessions')
    end

    it { expect(response).to have_http_status(:created) }

    it 'origin and outcome same' do
      expect(intervention_was.delete(['status'])).to eq(intervention_cloned.delete(['status']))
    end

    it 'status to draft' do
      expect(intervention_cloned['status']).to eq('draft')
    end

    it 'correctly clone questions to cloned session' do
      expect(cloned_questions.map(&:attributes)).to include(
        include(
          'subtitle' => 'Question Subtitle',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => '' }
          ),
          'formula' => {
            'payload' => 'var + 3',
            'patterns' => [
              { 'match' => '=7', 'target' => { 'id' => cloned_questions.second.id, 'type' => 'Question::Single' } }
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
              { 'match' => '=3', 'target' => { 'id' => cloned_sessions.second.id, 'type' => 'Session' } }
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

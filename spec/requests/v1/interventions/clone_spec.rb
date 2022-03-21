# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention, position: 1) }
  let!(:other_session) do
    create(:session, intervention: intervention, position: 2,
                     formula: { 'payload' => 'var + 2',
                                'patterns' =>
                        [{ 'match' => '=1',
                           'target' =>
                             [{ 'id' => third_session.id, 'type' => 'Session' }] }] })
  end
  let!(:third_session) do
    create(:session, intervention: intervention, position: 3,
                     formula: { 'payload' => '',
                                'patterns' =>
                        [{ 'match' => '',
                           'target' =>
                             [{ 'id' => '', 'type' => 'Session' }] }] })
  end
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:question1) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                             formula: { 'payload' => 'var + 3', 'patterns' => [
                               { 'match' => '=7', 'target' => [{ 'id' => question2.id, type: 'Question::Single' }] }
                             ] })
  end
  let!(:question2) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2,
                             formula: { 'payload' => 'var + 4', 'patterns' => [
                               { 'match' => '=3', 'target' => [{ 'id' => other_session.id, type: 'Session' }] }
                             ] })
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { post clone_v1_intervention_path(id: intervention.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post clone_v1_intervention_path(id: intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  shared_examples 'permitted user' do
    context 'when user clones an intervention' do
      before { request }

      let(:cloned_intervention_object) { Intervention.find(json_response['data']['id']) }
      let(:cloned_sessions) { cloned_intervention_object.sessions.order(:position) }
      let(:cloned_questions) { cloned_sessions.first.questions.order(:position) }
      let(:second_cloned_session) { cloned_sessions.second }
      let(:third_cloned_session) { cloned_sessions.third }

      let(:intervention_was) do
        intervention.attributes.except('id', 'created_at', 'updated_at')
      end

      let(:intervention_cloned) do
        json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'sessions')
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end

  context 'when user is researcher' do
    it_behaves_like 'permitted user'
  end

  context 'when user has multiple roles' do
    let(:user) { create(:user, :confirmed, roles: %w[guest researcher participant]) }

    it_behaves_like 'permitted user'
  end
end

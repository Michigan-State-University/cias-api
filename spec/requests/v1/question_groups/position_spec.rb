# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/question_groups/position', type: :request do
  let(:user) { create(:user, :researcher) }
  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group1) { create(:question_group, session: session, position: 3) }
  let!(:question_group2) { create(:question_group, session: session, position: 4) }
  let!(:question_group3) { create(:question_group, session: session, position: 5) }
  let(:request) do
    patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                            headers: user.create_new_auth_token
  end

  let(:params) do
    {
      question_group: {
        position: [
          {
            id: question_group1.id,
            position: 6
          },
          {
            id: question_group2.id,
            position: 7
          },
          {
            id: question_group3.id,
            position: 8
          }
        ]
      }
    }
  end

  context 'when authenticated as researcher user' do
    context 'when question group does not have questions' do
      it 'returns serialized cloned question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq 4
        expect(question_group1.reload.position).to eq 6
        expect(question_group2.reload.position).to eq 7
        expect(question_group3.reload.position).to eq 8
      end
    end

    context 'when position is sent as a single object instead of an array' do
      let(:params) { { question_group: { position: { id: question_group1.id, position: 6 } } } }

      before { request }

      it { expect(response).to have_http_status(:bad_request) }

      it 'does not change position' do
        expect(question_group1.reload.position).to eq 3
      end
    end

    context 'when question_group key is missing' do
      let(:params) { { position: [{ id: question_group1.id, position: 6 }] } }

      before { request }

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'when a group of another session is in the list' do
      let(:other_group) { create(:question_group, session: create(:session, intervention: session.intervention), position: 9) }
      let(:params) { { question_group: { position: [{ id: question_group1.id, position: 6 }, { id: other_group.id, position: 1 }] } } }

      before { request }

      it { expect(response).to have_http_status(:not_found) }

      it 'does not change positions' do
        expect([question_group1.reload.position, other_group.reload.position]).to eq [3, 9]
      end
    end

    context 'when a position is not a whole number' do
      let(:params) { { question_group: { position: [{ id: question_group1.id, position: 'abc' }] } } }

      before { request }

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(question_group1.reload.position).to eq 3 }
    end

    it 'updates the positions in one statement, without audits or versions' do
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] if payload[:sql].start_with?('UPDATE "question_groups"') }

      expect { ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { request } }.not_to(change do
        [Audited::Audit.where(auditable_type: 'QuestionGroup').count, PaperTrail::Version.where(item_type: 'QuestionGroup').count]
      end)
      expect(statements.size).to eq 1
    end
  end

  context 'when the session belongs to another researcher' do
    let(:other_researcher) { create(:user, :researcher) }
    let(:request) do
      patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                              headers: other_researcher.create_new_auth_token
    end

    before { request }

    it { expect(response).to have_http_status(:not_found) }
    it { expect(question_group1.reload.position).to eq 3 }
  end

  context 'when a collaborator can only view the intervention' do
    let(:viewer) { create(:user, :researcher) }
    let(:request) do
      patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                              headers: viewer.create_new_auth_token
    end

    before do
      create(:collaborator, intervention: session.intervention, user: viewer, view: true, edit: false)
      request
    end

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(question_group1.reload.position).to eq 3 }
  end

  context 'when an edit collaborator is not the current editor' do
    let(:collaborator) { create(:user, :researcher) }
    let(:request) do
      patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                              headers: collaborator.create_new_auth_token
    end

    before do
      create(:collaborator, intervention: session.intervention, user: collaborator, edit: true)
      request
    end

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(question_group1.reload.position).to eq 3 }
  end

  context 'when an e-intervention admin of the organization can read the session but cannot update it' do
    let(:organization) { create(:organization) }
    let!(:session) { create(:session, intervention: create(:intervention, user: user, organization: organization)) }
    let(:e_intervention_admin) { create(:user, :confirmed, roles: %w[researcher e_intervention_admin], organizable: organization) }
    let(:request) do
      patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                              headers: e_intervention_admin.create_new_auth_token
    end

    before { request }

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(question_group1.reload.position).to eq 3 }
  end
end

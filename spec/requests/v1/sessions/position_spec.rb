# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/position', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session1) { create(:session, position: 4, intervention: intervention) }
  let(:session2) { create(:session, position: 5, intervention: intervention) }
  let(:session3) { create(:session, position: 6, intervention: intervention) }
  let(:params) do
    {
      session: {
        position: [
          {
            id: session1.id,
            position: 11
          },
          {
            id: session2.id,
            position: 22
          },
          {
            id: session3.id,
            position: 33
          }
        ]
      }
    }
  end
  let(:request) do
    patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params,
                                                                                    headers: user.create_new_auth_token
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before { request }

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'proper order' do
        positions = json_response['data'].map { |session| session['attributes']['position'] }
        expect(positions).to eq [11, 22, 33]
      end
    end
  end

  context 'when position is not a list' do
    let(:params) { { session: { position: 'x' } } }

    before do
      [session1, session2, session3]
      request
    end

    it 'returns bad request' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'does not change positions' do
      expect([session1, session2, session3].map { |session| session.reload.position }).to eq [4, 5, 6]
    end
  end

  context 'when the caller cannot update the intervention' do
    let(:other_researcher) { create(:user, :confirmed, :researcher) }
    let(:request) do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params,
                                                                                      headers: other_researcher.create_new_auth_token
    end

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not change positions' do
      expect([session1, session2, session3].map { |session| session.reload.position }).to eq [4, 5, 6]
    end
  end

  context 'when a session of another intervention is in the list' do
    let(:other_session) { create(:session, position: 7, intervention: create(:intervention, user: user)) }
    let(:params) { { session: { position: [{ id: session1.id, position: 11 }, { id: other_session.id, position: 1 }] } } }

    before { request }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not change positions' do
      expect([session1.reload.position, other_session.reload.position]).to eq [4, 7]
    end
  end

  context 'when the intervention has collaborators' do
    let(:collaborator) { create(:user, :confirmed, :researcher) }
    let(:request) do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params,
                                                                                      headers: collaborator.create_new_auth_token
    end

    before { create(:collaborator, intervention: intervention, user: collaborator, edit: true) }

    it 'forbids a collaborator who is not the current editor' do
      request

      expect(response).to have_http_status(:forbidden)
      expect(session1.reload.position).to eq 4
    end

    it 'lets the current editor reorder' do
      intervention.update_column(:current_editor_id, collaborator.id)
      request

      expect(response).to have_http_status(:ok)
      expect([session1, session2, session3].map { |session| session.reload.position }).to eq [11, 22, 33]
    end
  end

  context 'when a value is malformed' do
    before { request }

    context 'with a position that is not a whole number' do
      let(:params) { { session: { position: [{ id: session1.id, position: '1.5' }] } } }

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(session1.reload.position).to eq 4 }
    end

    context 'with an id that is not a UUID' do
      let(:params) { { session: { position: [{ id: "#{session1.id}'", position: 11 }] } } }

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(session1.reload.position).to eq 4 }
    end

    context 'with the same session twice' do
      let(:params) { { session: { position: [{ id: session1.id, position: 11 }, { id: session1.id, position: 12 }] } } }

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(session1.reload.position).to eq 4 }
    end
  end

  it 'writes no audits or versions for the sessions' do
    [session1, session2, session3]

    expect { request }.not_to(change do
      [Audited::Audit.where(auditable_type: 'Session').count, PaperTrail::Version.where(item_type: 'Session').count]
    end)
  end
end

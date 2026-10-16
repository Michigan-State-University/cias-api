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

  context 'when position params are malicious' do
    context 'when position contains an SQL expression' do
      let(:params) { { session: { position: [{ id: session1.id, position: '7+(SELECT 770)' }] } } }

      before { request }

      it 'does not evaluate it' do
        pending 'BUG: position is interpolated into position_bulk_update.sql.erb, so the subquery is executed (SQL injection)'
        expect(session1.reload.position).not_to eq(777)
      end
    end

    context 'when id contains a quote' do
      let(:params) { { session: { position: [{ id: "x'", position: 1 }] } } }

      before { request }

      it 'does not break the SQL statement' do
        pending 'BUG: id is interpolated into a string literal in position_bulk_update.sql.erb, a quote ends it (SQL syntax error)'
        expect(response.body).not_to include('PG::SyntaxError')
      end
    end

    context 'when session belongs to another researcher' do
      let(:other_intervention) { create(:intervention, user: create(:user, :confirmed, :researcher)) }
      let!(:other_session) { create(:session, position: 1, intervention: other_intervention) }
      let(:params) { { session: { position: [{ id: other_session.id, position: 99 }] } } }

      before { request }

      it 'does not change its position' do
        pending 'BUG: Resource::Position updates any session by id, ignoring intervention_id and per-record access (IDOR)'
        expect(other_session.reload.position).to eq(1)
      end
    end
  end
end

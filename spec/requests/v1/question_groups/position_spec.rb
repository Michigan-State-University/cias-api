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

    context 'when position params are malicious' do
      context 'when position contains an SQL expression' do
        let(:params) { { question_group: { position: [{ id: question_group1.id, position: '7+(SELECT 770)' }] } } }

        before { request }

        it 'does not evaluate it' do
          pending 'BUG: position is interpolated into position_bulk_update.sql.erb, so the subquery is executed (SQL injection)'
          expect(question_group1.reload.position).not_to eq(777)
        end
      end

      context 'when id contains a quote' do
        let(:params) { { question_group: { position: [{ id: "x'", position: 1 }] } } }

        before { request }

        it 'does not break the SQL statement' do
          pending 'BUG: id is interpolated into a string literal in position_bulk_update.sql.erb, a quote ends it (SQL syntax error)'
          expect(response.body).not_to include('PG::SyntaxError')
        end
      end

      context 'when question group belongs to another researcher' do
        let(:other_session) { create(:session, intervention: create(:intervention, user: create(:user, :researcher))) }
        let!(:other_question_group) { create(:question_group, session: other_session, position: 1) }
        let(:params) { { question_group: { position: [{ id: other_question_group.id, position: 99 }] } } }

        before { request }

        it 'does not change its position' do
          pending 'BUG: Resource::Position updates any question group by id, ignoring session_id and per-record access (IDOR)'
          expect(other_question_group.reload.position).to eq(1)
        end
      end
    end
  end
end

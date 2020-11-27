# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let(:shared_to) { :registered }
  let(:intervention_user) { admin }
  let(:sessions) { create_list(:session, 2) }
  let(:users) { [] }
  let!(:intervention) { create(:intervention, :published, name: 'Some intervention', user: intervention_user, sessions: sessions, shared_to: shared_to) }

  context 'when user' do
    before { get v1_intervention_path(intervention.id), headers: user.create_new_auth_token }

    context 'has role admin' do
      it 'contains proper attributes' do
        expect(json_response).to include(
          'name' => 'Some intervention',
          'shared_to' => 'registered'
        )
      end

      it 'contains proper sessions collection' do
        expect(json_response['sessions_size']).to eq sessions.size
      end
    end

    context 'has role participant' do
      let(:user) { participant }

      context 'intervention is allowed for anyone or registered users' do
        let(:shared_to) { %w[anyone registered].sample }

        it 'contains proper attributes' do
          expect(json_response).to include(
            'name' => 'Some intervention',
            'shared_to' => shared_to
          )
        end

        it 'contains proper sessions collection' do
          expect(json_response['sessions_size']).to eq sessions.size
        end
      end

      context 'intervention is allowed for invited users' do
        let(:shared_to) { 'invited' }

        context 'user does not have an access' do
          it 'contains empty data' do
            expect(json_response['data']).not_to be_present
          end
        end

        context 'user has an access' do
          let(:users) { [participant] }

          xit 'contains proper attributes' do
            expect(json_response).to include(
              'name' => 'Some intervention',
              'shared_to' => shared_to
            )
          end

          xit 'contains proper sessions collection' do
            expect(json_response['sessions_size']).to eq sessions.size
          end
        end
      end
    end

    context 'has role researcher' do
      let(:user) { researcher }

      context 'intervention does not belong to him' do
        it 'contains empty data' do
          expect(json_response['data']).not_to be_present
        end
      end

      context 'intervention belongs to him' do
        let(:intervention_user) { researcher }

        it 'contains proper attributes' do
          expect(json_response).to include(
            'name' => 'Some intervention',
            'shared_to' => 'registered'
          )
        end

        it 'contains proper sessions collection' do
          expect(json_response['sessions_size']).to eq 2
        end
      end
    end

    context 'has role guest' do
      let(:user) { guest }

      context 'intervention is not allowed for anyone' do
        it 'contains empty data' do
          expect(json_response['data']).not_to be_present
        end
      end

      context 'intervention is allowed for guests' do
        let(:shared_to) { 'anyone' }

        it 'contains proper attributes' do
          expect(json_response).to include(
            'name' => 'Some intervention',
            'shared_to' => 'anyone'
          )
        end

        it 'contains proper sessions collection' do
          expect(json_response['sessions_size']).to eq sessions.size
        end
      end
    end
  end
end

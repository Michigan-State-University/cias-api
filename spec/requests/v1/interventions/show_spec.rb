# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'researcher' => researcher,
      'user_with_multiple_roles' => user_with_multiple_roles
    }
  end

  let(:shared_to) { 'registered' }
  let(:intervention_user) { admin }
  let(:sessions) { create_list(:session, 2) }
  let!(:intervention) do
    create(:intervention, :published, name: 'Some intervention',
                                      user: intervention_user, sessions: sessions, shared_to: shared_to,
                                      reports: reports)
  end
  let(:reports) { [] }
  let(:csv_attachment) { fixture_file_upload(Rails.root.join('spec/factories/csv/test_empty.csv'), 'text/csv') }

  let(:attrs) { json_response['data']['attributes'] }

  context 'when user' do
    before { get v1_intervention_path(intervention.id), headers: user.create_new_auth_token }

    %w[researcher user_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      context 'has role admin' do
        it 'contains proper sessions collection' do
          expect(attrs['sessions'].size).to eq sessions.size
        end

        context 'when intervention does not contain any report' do
          it 'contains proper attributes' do
            expect(attrs).to include(
              'name' => 'Some intervention',
              'shared_to' => shared_to,
              'csv_link' => nil,
              'csv_generated_at' => nil
            )
          end
        end

        context 'when intervention contains some report' do
          let!(:reports) { [csv_attachment] }

          it 'contains proper attributes' do
            expect(attrs).to include(
              'name' => 'Some intervention',
              'shared_to' => shared_to,
              'csv_link' => include('test_empty.csv'),
              'csv_generated_at' => be_present
            )
          end
        end
      end
    end

    context 'has role participant' do
      let(:user) { participant }

      context 'intervention is allowed for anyone or registered users' do
        let(:shared_to) { %w[anyone registered].sample }

        it 'returns :not_found http status code' do
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'intervention is allowed for invited users' do
        let(:shared_to) { 'invited' }

        context 'user does not have an access' do
          it 'contains empty data' do
            expect(json_response['data']).not_to be_present
          end

          it 'returns :not_found http status code' do
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'user has an access' do
          let!(:invitation) { create(:intervention_invitation, invitable: intervention, email: participant.email) }

          before { get v1_intervention_path(intervention.id), headers: user.create_new_auth_token }

          it 'returns :not_found http status code' do
            expect(response).to have_http_status(:not_found)
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

        it 'returns :not_found http status code' do
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'intervention belongs to him' do
        let(:intervention_user) { researcher }

        it 'contains proper sessions collection' do
          expect(attrs['sessions'].size).to eq 2
        end

        context 'when intervention does not contain any report' do
          it 'contains proper attributes' do
            expect(attrs).to include(
              'name' => 'Some intervention',
              'shared_to' => shared_to,
              'csv_link' => nil,
              'csv_generated_at' => nil
            )
          end
        end

        context 'when intervention contains some report' do
          let!(:reports) { [csv_attachment] }

          it 'contains proper attributes' do
            expect(attrs).to include(
              'name' => 'Some intervention',
              'shared_to' => shared_to,
              'csv_link' => include('test_empty.csv'),
              'csv_generated_at' => be_present
            )
          end
        end
      end
    end

    context 'has role guest' do
      let(:user) { guest }

      context 'intervention is not allowed for anyone' do
        it 'contains empty data' do
          expect(json_response['data']).not_to be_present
        end

        it 'returns :not_found http status code' do
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'intervention is allowed for guests' do
        let(:shared_to) { 'anyone' }

        it 'returns :not_found http status code' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end

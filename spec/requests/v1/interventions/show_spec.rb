# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }

  let(:shared_to) { 'registered' }
  let(:intervention_user) { admin }
  let(:sessions) { create_list(:session, 2) }
  let(:organization) { create(:organization) }
  let!(:intervention) do
    create(:intervention, :published, name: 'Some intervention',
                                      user: intervention_user, sessions: sessions, shared_to: shared_to,
                                      organization: organization, reports: reports)
  end
  let(:reports) { [] }
  let(:csv_attachment) { FactoryHelpers.upload_file('spec/factories/csv/test_empty.csv', 'text/csv', true) }

  let(:attrs) { json_response['data']['attributes'] }
  let(:response_sessions) { json_response['data']['relationships']['sessions']['data'] }

  context 'when user' do
    before { get v1_intervention_path(intervention.id), headers: user.create_new_auth_token }

    shared_examples 'permitted user' do
      it 'contains proper sessions collection' do
        expect(response_sessions.size).to eq sessions.size and expect(attrs['sessions_size']).to eq sessions.size
      end

      it 'conteins information about first session language' do
        expect(attrs).to include(
          'first_session_language' => 'English (United States)'
        )
      end

      context 'when intervention does not contain any report' do
        it 'contains proper attributes' do
          expect(attrs).to include(
            'name' => 'Some intervention',
            'shared_to' => shared_to,
            'csv_link' => nil,
            'csv_generated_at' => nil,
            'organization_id' => organization.id,
            'google_language_id' => intervention.google_language_id
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

      context 'when intervention has field from_deleted_organization set on true' do
        let!(:intervention_with_deleted_organization) do
          create(:intervention, name: 'Some intervention with deleted organization',
                                user: intervention_user, from_deleted_organization: true)
        end

        it 'does not contain intervention from deleted organization' do
          expect(attrs).not_to include(
            'name' => 'Some intervention with deleted organization',
            'organization_id' => nil
          )
        end
      end
    end

    context 'user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'user has multiple roles' do
      let(:user) { user_with_multiple_roles }

      it_behaves_like 'permitted user'
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
          expect(response_sessions.size).to eq 2 and expect(attrs['sessions_size']).to eq 2
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

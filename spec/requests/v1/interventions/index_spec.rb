# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'user_with_admin_role' => user_with_multiple_roles
    }
  end

  let!(:admin_interventions) { create_list(:intervention, 3, :published, user: admin, shared_to: :registered) }
  let!(:researcher_interventions) { create_list(:intervention, 3, :published, user: researcher, shared_to: :invited) }
  let!(:interventions_for_guests) { create_list(:intervention, 2, :published) }
  let(:organization) { create(:organization) }
  let!(:intervention_for_organization) { [create(:intervention, organization_id: organization.id)] }

  let!(:params) { {} }

  shared_examples 'chosen users' do |interventions_size_admin, interventions_size_researcher|
    context 'when user is' do
      before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

      %w[admin user_with_admin_role].each do |role|
        let(:user) { users[role] }
        context role do
          let(:interventions_scope) { admin_interventions + researcher_interventions + interventions_for_guests + intervention_for_organization }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns proper interventions' do
            expect(json_response['interventions'].pluck('id')).to match_array interventions_scope.sort_by(&:created_at).reverse
                                                                                  .take(interventions_size_admin).map(&:id)
          end

          it 'returns correct invitations list size' do
            expect(json_response['interventions'].size).to eq interventions_size_admin
          end
        end
      end

      context 'participant' do
        let(:user) { participant }
        let(:interventions_scope) { admin_interventions + interventions_for_guests }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper error message' do
          expect(json_response['interventions'].pluck('id')).to match_array []
        end

        it 'returns correct invitations list size' do
          expect(json_response['interventions'].size).to eq 0
        end
      end

      context 'researcher' do
        let(:user) { researcher }
        let(:interventions_scope) { researcher_interventions }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper interventions' do
          expect(json_response['interventions'].pluck('id')).to match_array interventions_scope.sort_by(&:created_at).reverse
                                                                                .take(interventions_size_researcher).map(&:id)
        end

        it 'returns correct invitations list size' do
          expect(json_response['interventions'].size).to eq interventions_size_researcher
        end
      end

      context 'guest' do
        let(:user) { guest }
        let(:interventions_scope) { interventions_for_guests }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper interventions' do
          expect(json_response['interventions'].pluck('id')).to match_array []
        end

        it 'returns correct invitations list size' do
          expect(json_response['interventions'].size).to eq 0
        end
      end
    end
  end

  context 'when params are given' do
    let!(:params) { { start_index: 0, end_index: 1 } }

    it_behaves_like 'chosen users', 2, 2
  end

  context 'when params are not given' do
    it_behaves_like 'chosen users', 9, 3
  end

  context 'filtering by statuses' do
    let!(:params) { { statuses: %w[closed archived] } }
    let!(:archived_intervention) { create(:intervention, :archived, user: admin, shared_to: :registered) }
    let!(:closed_intervention) { create(:intervention, :closed, user: admin, shared_to: :registered) }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct size' do
      expect(json_response['interventions'].size).to be(2)
    end

    it 'return correct intervention' do
      expect(json_response['interventions'].pluck('id')).to include(archived_intervention.id, closed_intervention.id)
    end
  end

  context 'filtering by name' do
    let!(:params) { { name: 'New' } }
    let!(:new_intervention) { create(:intervention, :archived, user: admin, shared_to: :registered, name: 'New Intervention') }
    let!(:old_intervention) { create(:intervention, :closed, user: admin, shared_to: :registered, name: 'Old Intervention') }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct size' do
      expect(json_response['interventions'].size).to be(1)
    end

    it 'return correct intervention' do
      expect(json_response['interventions'].first['id']).to include(new_intervention.id)
    end
  end
end

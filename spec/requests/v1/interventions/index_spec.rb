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
  let!(:intervention_for_organization) { create_list(:intervention, 3, organization_id: organization.id, user: researcher) }

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
            expect(json_response['data'].pluck('id')).to match_array interventions_scope.sort_by(&:created_at).reverse
                                                                                        .take(interventions_size_admin).map(&:id)
          end

          it 'returns correct invitations list size' do
            expect(json_response['data'].size).to eq interventions_size_admin
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
          expect(json_response['data'].pluck('id')).to match_array []
        end

        it 'returns correct invitations list size' do
          expect(json_response['data'].size).to eq 0
        end
      end

      context 'researcher' do
        let(:user) { researcher }
        let(:interventions_scope) { researcher_interventions + intervention_for_organization }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper interventions' do
          expect(json_response['data'].pluck('id')).to match_array interventions_scope.sort_by(&:created_at).reverse
                                                                                      .take(interventions_size_researcher).map(&:id)
        end

        it 'returns correct invitations list size' do
          expect(json_response['data'].size).to eq interventions_size_researcher
        end

        context 'filtering by organization' do
          let!(:params) { { organization_id: organization.id } }

          it 'return correct status' do
            expect(response).to have_http_status(:ok)
          end

          it 'return correct data' do
            expect(json_response['data'].size).to eq intervention_for_organization.size
            expect(json_response['data'].pluck('id')).to match_array intervention_for_organization.map(&:id)
          end
        end
      end

      context 'guest' do
        let(:user) { guest }
        let(:interventions_scope) { interventions_for_guests }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper interventions' do
          expect(json_response['data'].pluck('id')).to match_array []
        end

        it 'returns correct invitations list size' do
          expect(json_response['data'].size).to eq 0
        end
      end
    end
  end

  context 'when params are given' do
    let!(:params) { { start_index: 0, end_index: 1 } }

    it_behaves_like 'chosen users', 2, 2
  end

  context 'when params are not given' do
    it_behaves_like 'chosen users', 11, 6
  end

  context 'filtering by statuses' do
    let!(:params) { { statuses: %w[closed archived] } }
    let!(:archived_intervention) { create(:intervention, :archived, user: admin, shared_to: :registered) }
    let!(:closed_intervention) { create(:intervention, :closed, user: admin, shared_to: :registered) }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct size' do
      expect(json_response['data'].size).to be(2)
    end

    it 'return correct intervention' do
      expect(json_response['data'].pluck('id')).to include(archived_intervention.id, closed_intervention.id)
    end
  end

  context 'filtering by name' do
    let!(:params) { { name: 'New' } }
    let!(:new_intervention) { create(:intervention, :archived, user: admin, shared_to: :registered, name: 'New Intervention') }
    let!(:old_intervention) { create(:intervention, :closed, user: admin, shared_to: :registered, name: 'Old Intervention') }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct size' do
      expect(json_response['data'].size).to be(1)
    end

    it 'return correct intervention' do
      expect(json_response['data'].first['id']).to include(new_intervention.id)
    end
  end

  context 'returns only interventions that are not being cloned' do
    let!(:intervention_being_cloned) { create(:intervention, user: admin, is_hidden: true) }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct intervention' do
      expect(json_response['data'].pluck('id')).to not_include(intervention_being_cloned.id)
    end
  end

  context 'return only intervention being shared with current_user' do
    let!(:shared_intervention) { create(:intervention, collaborators: [create(:collaborator, user: user)]) }
    let(:params) { { only_shared_with_me: true } }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct intervention' do
      expect(json_response['data'].pluck('id')).to include(shared_intervention.id)
    end
  end

  context 'return only intervention being shared with others' do
    let!(:shared_intervention) { create(:intervention, :with_collaborators, user: user) }
    let(:params) { { only_shared_by_me: true } }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct intervention' do
      expect(json_response['data'].pluck('id')).to include(shared_intervention.id)
    end
  end

  context 'return only intervention not shared with anyone' do
    let!(:shared_intervention) { create(:intervention, :with_collaborators) }
    let!(:intervention_another_researcher) { create(:intervention) }
    let(:params) { { only_not_shared_with_anyone: true } }

    before { get v1_interventions_path, params: params, headers: user.create_new_auth_token }

    it 'return correct intervention' do
      expect(json_response['data'].pluck('id')).to not_include(shared_intervention.id).and not_include(intervention_another_researcher.id)
    end
  end

  context 'when some interventions are starred' do
    let(:other_researcher) { create(:user, :confirmed, :researcher) }

    let!(:interventions) do
      create_list(:intervention, 30, user: other_researcher) { |intervention, index| intervention.created_at = DateTime.now + index.hours }
    end

    let(:request) { get v1_interventions_path, params: params, headers: other_researcher.create_new_auth_token }

    let(:random_sample) { (0...30).to_a.sample(15) }
    let(:correct_index_order) { (0...30).sort_by { |index| [random_sample.count(index), index] }.reverse }

    before do
      random_sample.each do |index|
        Star.create(user_id: other_researcher.id, intervention_id: interventions[index].id)
      end

      request
    end

    it 'lists the starred interventions before the unstarred ones' do
      expect(json_response['data'].pluck('id')).to eq(correct_index_order.map { |index| interventions[index].id })
    end

    context 'when other user with access to the interventions will have other interventions starred' do
      let(:other_admin) { create(:user, :confirmed, :admin) }

      before do
        (0...30).to_a.sample(10).each do |index|
          Star.create(user_id: other_admin.id, intervention_id: interventions[index].id)
        end
      end

      it 'lists the starred interventions before the unstarred ones' do
        expect(json_response['data'].pluck('id')).to eq(correct_index_order.map { |index| interventions[index].id })
      end
    end
  end
end

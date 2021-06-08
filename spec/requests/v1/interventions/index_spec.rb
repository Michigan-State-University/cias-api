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
  let!(:intervention_for_organization) { create(:intervention, organization_id: organization.id) }

  context 'when user is' do
    before { get v1_interventions_path, headers: user.create_new_auth_token }

    %w[admin user_with_admin_role].each do |role|
      let(:user) { users[role] }
      context role do
        let(:interventions_scope) { admin_interventions + researcher_interventions + interventions_for_guests }

        it 'returns proper interventions' do
          expect(json_response['interventions'].pluck('id')).to match_array interventions_scope.map(&:id)
        end
      end
    end

    context 'has role participant' do
      let(:user) { participant }
      let(:interventions_scope) { admin_interventions + interventions_for_guests }

      it 'returns proper error message' do
        expect(json_response['interventions'].pluck('id')).to match_array []
      end
    end

    context 'has role researcher' do
      let(:user) { researcher }
      let(:interventions_scope) { researcher_interventions }

      it 'returns proper interventions' do
        expect(json_response['interventions'].pluck('id')).to match_array interventions_scope.map(&:id)
      end
    end

    context 'has role guest' do
      let(:user) { guest }
      let(:interventions_scope) { interventions_for_guests }

      it 'returns proper interventions' do
        expect(json_response['interventions'].pluck('id')).to match_array []
      end
    end
  end
end

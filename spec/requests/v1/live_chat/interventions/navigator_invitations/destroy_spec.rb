# frozen_string_literal: true

RSpec.describe 'DELETE /v1/interventions/:intervention_id/navigators/invitations/:id', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    delete v1_intervention_navigators_invitation_path(intervention_id: intervention.id, id: invitation_id), headers: headers
  end
  let!(:navigator_invitation) { create(:navigator_invitation, intervention: intervention) }
  let!(:accepted_invitation) { create(:navigator_invitation, :confirmed, intervention: intervention) }

  let(:invitation_id) { navigator_invitation.id }

  context 'when user has access and pass correct invitation' do
    it 'returns correct status code (OK)' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'delete invitation' do
      expect { request }.to change(LiveChat::Interventions::NavigatorInvitation, :count).by(-1)
    end
  end

  context 'when invitation is already accepted' do
    let(:invitation_id) { accepted_invitation.id }

    it 'return correct msg and status code' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find LiveChat::Interventions::NavigatorInvitation with 'id'")
    end
  end

  context 'other researcher' do
    let(:other_researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { other_researcher.create_new_auth_token }

    it 'return correct status code and msg' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find Intervention with 'id'=")
    end
  end

  context 'when user has no permission' do
    before { request }

    %i[participant guest health_system_admin organization_admin].each do |role|
      context "current user is #{role}" do
        let(:other_user) { create(:user, :confirmed, role) }
        let(:headers) { other_user.create_new_auth_token }

        it do
          expect(response).to have_http_status(:forbidden)
          expect(json_response['message']).to include('You are not authorized to access this page.')
        end
      end
    end
  end
end

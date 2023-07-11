# frozen_string_literal: true

RSpec.describe 'DELETE /v1/interventions/:intervention_id/accesses/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:flexible_order_intervention, shared_to: 'registered', user: user) }
  let(:accesses) do
    InterventionAccess.create!([
                                 { email: 'mike.wazowski@gmail.com', intervention: intervention },
                                 { email: 'michael.myers@gmail.com', intervention: intervention },
                                 { email: 'handsome.jack@gmail.com', intervention: intervention }
                               ])
  end

  context 'correctly deletes access' do
    let(:request) { delete v1_intervention_access_path(intervention_id: intervention.id, id: accesses[0].id), headers: user.create_new_auth_token }

    before { request }

    it 'returns correct HTTP status code (No Content)' do
      expect(response).to have_http_status(:no_content)
    end

    it 'correctly deletes access from database' do
      expect(InterventionAccess.count).to eq(accesses.size - 1)
      expect(intervention.reload.intervention_accesses.size).to eq(accesses.size - 1)
    end
  end

  context 'when current user is collaborator' do
    let(:request) { delete v1_intervention_access_path(intervention_id: intervention.id, id: accesses[0].id), headers: user.create_new_auth_token }
    let(:intervention) { create(:intervention) }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
    let(:user) { collaborator.user }

    before { request }

    it {
      expect(response).to have_http_status(:forbidden)
    }

    context 'when has edit access' do
      let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: true) }

      it { expect(response).to have_http_status(:no_content) }
    end
  end
end

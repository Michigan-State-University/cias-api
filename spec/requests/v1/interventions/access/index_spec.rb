# frozen_string_literal: true

RSpec.describe 'GET /v1/interventions/:intervention_id/accesses', type: :request do
  let_it_be(:owner) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: owner) }
  let_it_be(:other_intervention) { create(:intervention, user: owner) }
  let_it_be(:emails) { %w[mike.wazowski@gmail.com michael.myers@gmail.com handsome.jack@gmail.com] }
  let_it_be(:accesses) do
    emails.map { |email| InterventionAccess.create!(email: email, intervention: intervention) }
  end
  let_it_be(:other_access) { InterventionAccess.create!(email: 'not.listed@gmail.com', intervention: other_intervention) }

  let(:user) { owner.reload }
  let(:headers) { user.create_new_auth_token }
  let(:intervention_id) { intervention.id }
  let(:request) { get v1_intervention_accesses_path(intervention_id: intervention_id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_intervention_accesses_path(intervention_id: intervention_id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  it_behaves_like 'deactivated account'

  shared_examples 'returns intervention accesses' do
    it 'returns correct HTTP status (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns only accesses of the requested intervention' do
      expect(json_response['data'].pluck('id')).to match_array(accesses.map { |access| access.id.to_s })
    end

    it 'returns emails and correct type' do
      expect(json_response['data'].map { |access| access['attributes']['email'] }).to match_array(emails)
      expect(json_response['data'].pluck('type')).to all(eq('intervention_access'))
    end
  end

  context 'when current user is the intervention owner' do
    before { request }

    it_behaves_like 'returns intervention accesses'
  end

  context 'when current user is admin' do
    let(:user) { create(:user, :confirmed, :admin) }

    before { request }

    it_behaves_like 'returns intervention accesses'
  end

  context 'when current user is collaborator with view access' do
    let(:user) { create(:user, :confirmed, :researcher) }

    before do
      create(:collaborator, intervention: intervention, user: user, view: true, edit: false)
      request
    end

    it_behaves_like 'returns intervention accesses'
  end

  context 'when intervention has no accesses' do
    let(:intervention_id) { create(:intervention, user: owner).id }

    before { request }

    it 'returns empty collection' do
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end
  end

  context 'when intervention does not exist' do
    let(:intervention_id) { 'non-existing-id' }

    before { request }

    it 'returns correct HTTP status (Not Found)' do
      expect(response).to have_http_status(:not_found)
    end
  end

  # The index action calls no `authorize!` and does not scope through `accessible_by`,
  # so any signed-in user can list the access emails of any intervention.
  context 'when current user has no access to the intervention' do
    before { request }

    context 'when user is a researcher who neither owns nor collaborates on it' do
      let(:user) { create(:user, :confirmed, :researcher) }

      it 'does not return access list' do
        pending 'BUG: AccessesController#index has no authorization check and leaks emails to unrelated researchers'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is a participant' do
      let(:user) { create(:user, :confirmed, :participant) }

      it 'does not return access list' do
        pending 'BUG: AccessesController#index has no authorization check and leaks emails to participants'
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

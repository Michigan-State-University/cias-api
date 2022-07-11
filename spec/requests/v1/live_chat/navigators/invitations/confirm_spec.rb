# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/navigators/invitations/confirm', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:request) do
    get v1_live_chat_navigators_confirm_path, params: {
      intervention_id: intervention.id, email: invited_email
    }
  end

  context 'Correctly assigns existing navigator to intervention' do
    let(:navigator) { create(:user, :researcher, :confirmed) }
    let(:invited_email) { navigator.email }

    before { V1::LiveChat::InviteNavigators.call([navigator.email], intervention) }

    it do
      expect { request }.to change { intervention.reload.navigators.count }.by(1)
    end
  end

  context 'Error behaviour' do
    context 'Returns 404 status code when no invitation present' do
      let(:navigator) { create(:user, :researcher, :confirmed) }
      let(:invited_email) { navigator.email }

      it do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

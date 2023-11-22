# frozen_string_literal: true

RSpec.shared_examples 'deactivated account' do
  context 'when current user is deactivated' do
    let!(:user) { create(:user, :confirmed, active: false) }
    let(:headers) { user.create_new_auth_token }

    before do
      request
    end

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end

    it 'return expected message' do
      expect(json_response['message']).to eq 'This account has been deactivated. Please get in touch with the support if you think it is a mistake.'
    end
  end
end

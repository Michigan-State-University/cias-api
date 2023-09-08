# frozen_string_literal: true

RSpec.shared_examples 'users without access' do
  context 'other researcher' do
    let(:current_user) { create(:user, :researcher, :confirmed) }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'other role' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end

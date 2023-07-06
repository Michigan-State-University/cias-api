# frozen_string_literal: true

RSpec.shared_examples 'collaboration mode - only one editor at the same time' do
  context 'collaboration mode - only one editor at the same time' do
    let!(:intervention) { create(:intervention, user: user, current_editor: create(:user, :researcher)) }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: user, view: true, edit: true) }

    before { request }

    it {
      expect(response).to have_http_status(:forbidden)
    }
  end
end

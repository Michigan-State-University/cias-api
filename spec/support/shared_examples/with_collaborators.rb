# frozen_string_literal: true

RSpec.shared_examples 'correct behavior for the intervention with collaborators' do
  before { request }

  context 'with collaborators' do
    let(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: user) }

    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    context 'when current user isn\'t the current editor' do
      let(:intervention) { create(:intervention, :with_collaborators) }

      it 'return correct status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

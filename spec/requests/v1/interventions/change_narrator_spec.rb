# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/change_narrator', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      narrator: {
        name: 'emmi',
        replaced_animations: {
          'eatCracker' => 'acknowledge',
          'standStill' => 'restWeightShift'
        }
      }
    }
  end

  let(:request) { post v1_interventions_narrator_index_path(id: intervention.id), headers: headers, params: params }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_interventions_narrator_index_path(id: intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is researcher' do
    let(:model) { 'Intervention' }
    let(:object_id) { intervention.id }
    let(:new_character) { 'emmi' }
    let(:new_animations) do
      {
        'eatCracker' => 'acknowledge',
        'standStill' => 'restWeightShift'
      }
    end

    before do
      ActiveJob::Base.queue_adapter = :test
      allow(MultipleCharacters::ChangeNarratorJob).to receive(:perform_later).with(model, object_id, new_character, new_animations).and_return(true)
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'scheduled job' do
      request
      expect(MultipleCharacters::ChangeNarratorJob).to have_received(:perform_later)
    end
  end

  context 'when user has insufficient role' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'returns correct HTTP code (Forbidden)' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end

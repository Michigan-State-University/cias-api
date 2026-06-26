# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::PredefinedParticipants::FulfillRaSessionService do
  subject(:result) do
    described_class.call(
      intervention: intervention,
      participant: participant,
      fulfilled_by: researcher,
      health_clinic_id: nil
    )
  end

  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let!(:ra_session) { create(:ra_session, intervention: intervention) }
  let(:participant) { create(:user, :confirmed, :predefined_participant) }

  context 'when no RA user session exists yet' do
    it 'creates a UserIntervention' do
      expect { result }.to change(UserIntervention, :count).by(1)
    end

    it 'creates a UserSession::ResearchAssistant' do
      expect { result }.to change(UserSession::ResearchAssistant, :count).by(1)
    end

    it 'stamps the fulfilling researcher and marks it started' do
      expect(result.user_session.fulfilled_by_id).to eq(researcher.id)
      expect(result.user_session.started).to be(true)
    end

    it 'returns already_completed false' do
      expect(result.already_completed).to be(false)
    end
  end

  context 'when the RA session was already completed for the participant' do
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
    let!(:existing_user_session) do
      create(:ra_user_session, session: ra_session, user: participant,
                               user_intervention: user_intervention, finished_at: 1.day.ago)
    end

    it 'returns already_completed true' do
      expect(result.already_completed).to be(true)
    end

    it 'returns the existing session without creating a new one' do
      expect { result }.not_to change(UserSession::ResearchAssistant, :count)
      expect(result.user_session.id).to eq(existing_user_session.id)
    end
  end

  context 'when a different researcher takes over fulfillment' do
    let(:original_researcher) { create(:user, :researcher, :confirmed) }
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
    let!(:existing_user_session) do
      create(:ra_user_session, session: ra_session, user: participant,
                               user_intervention: user_intervention, fulfilled_by: original_researcher)
    end

    it 'updates fulfilled_by to the current researcher' do
      expect { result }.to change { existing_user_session.reload.fulfilled_by_id }
        .from(original_researcher.id).to(researcher.id)
    end
  end

  context 'when the intervention has no RA session' do
    before { ra_session.destroy }

    it 'raises RecordNotFound' do
      expect { result }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

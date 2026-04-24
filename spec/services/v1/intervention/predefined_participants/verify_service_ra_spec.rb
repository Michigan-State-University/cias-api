# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::PredefinedParticipants::VerifyService do
  subject(:result) { described_class.call(predefined_user_parameters) }

  let!(:predefined_participant) { create(:user, :predefined_participant) }
  let(:predefined_user_parameters) { predefined_participant.predefined_user_parameter }
  let(:intervention) { predefined_user_parameters.intervention }

  describe 'RA session integration — response keys' do
    it 'includes ra_session_pending and intervention_type' do
      expect(result.keys).to include(:ra_session_pending, :intervention_type)
    end

    it 'returns the intervention type' do
      expect(result[:intervention_type]).to eq(intervention.type)
    end
  end

  describe '#ra_session_pending?' do
    context 'when intervention has no RA session' do
      it 'returns false' do
        expect(result[:ra_session_pending]).to be(false)
      end
    end

    context 'when intervention has an RA session' do
      let!(:ra_session) { create(:ra_session, intervention: intervention) }

      context 'and no UserSession exists for the participant' do
        it 'returns true' do
          expect(result[:ra_session_pending]).to be(true)
        end

        it 'returns nil for session_id (participant is blocked)' do
          create_list(:session, 2, intervention: intervention)
          expect(result[:session_id]).to be_nil
        end
      end

      context 'and UserSession exists but is not finished' do
        before do
          user_intervention = create(:user_intervention, user: predefined_participant, intervention: intervention)
          create(:ra_user_session, session: ra_session, user: predefined_participant,
                                   user_intervention: user_intervention)
        end

        it 'returns true' do
          expect(result[:ra_session_pending]).to be(true)
        end
      end

      context 'and UserSession is completed' do
        before do
          user_intervention = create(:user_intervention, user: predefined_participant, intervention: intervention)
          create(:ra_user_session, session: ra_session, user: predefined_participant,
                                   user_intervention: user_intervention, finished_at: 1.day.ago)
        end

        it 'returns false' do
          expect(result[:ra_session_pending]).to be(false)
        end

        it 'returns the first Classic session for session_id' do
          classic_sessions = create_list(:session, 2, intervention: intervention)
          first_classic = classic_sessions.min_by(&:position)
          expect(result[:session_id]).to eq(first_classic.id)
        end
      end
    end
  end
end

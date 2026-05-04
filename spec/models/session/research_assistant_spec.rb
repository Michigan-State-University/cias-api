# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session::ResearchAssistant, type: :model do
  subject(:ra_session) { create(:ra_session) }

  let(:intervention) { ra_session.intervention }

  describe 'inheritance' do
    it 'inherits from Session' do
      expect(described_class.superclass).to eq(Session)
    end
  end

  describe 'validations' do
    describe '#single_ra_session_per_intervention' do
      it 'does not allow two RA sessions in the same intervention' do
        expect do
          create(:ra_session, intervention: intervention)
        end.to raise_error(ActiveRecord::RecordInvalid, /Research Assistant session/)
      end

      it 'allows RA sessions in different interventions' do
        other_intervention = create(:intervention)
        expect do
          create(:ra_session, intervention: other_intervention)
        end.not_to raise_error
      end
    end

    describe '#position_must_be_zero' do
      it 'is invalid with a non-zero position' do
        ra_session.position = 5
        expect(ra_session).not_to be_valid
        expect(ra_session.errors.added?(:position, :must_be_zero)).to be(true)
      end

      it 'is valid with position 0' do
        expect(ra_session.position).to eq(0)
        expect(ra_session).to be_valid
      end
    end

    describe '#no_cross_session_branching' do
      it 'is valid with no formulas' do
        ra_session.formulas = []
        expect(ra_session).to be_valid
      end

      it 'is invalid when formulas branch to another session' do
        ra_session.formulas = [
          {
            'payload' => '',
            'patterns' => [
              {
                'match' => '=1',
                'target' => [
                  { 'type' => 'Session::Classic', 'id' => SecureRandom.uuid }
                ]
              }
            ]
          }
        ]
        expect(ra_session).not_to be_valid
        expect(ra_session.errors.added?(:formulas, :ra_session_cannot_branch_to_other_sessions)).to be(true)
      end

      it 'is valid when formulas have no session targets' do
        ra_session.formulas = [
          {
            'payload' => '',
            'patterns' => [
              {
                'match' => '=1',
                'target' => [
                  { 'type' => 'Question', 'id' => SecureRandom.uuid }
                ]
              }
            ]
          }
        ]
        expect(ra_session).to be_valid
      end
    end
  end

  describe '#force_single_fill' do
    it 'forces multiple_fill to false on save' do
      ra_session.multiple_fill = true
      ra_session.save!
      expect(ra_session.reload.multiple_fill).to be(false)
    end
  end

  describe '#set_default_variable' do
    let(:fresh_intervention) { create(:intervention) }

    it 'defaults to "ra" when no other session uses that variable' do
      ra = described_class.new(name: 'RA', intervention: fresh_intervention)
      ra.valid? # triggers before_validation
      expect(ra.variable).to eq('ra')
    end

    it 'falls back to "ra_1" when "ra" is taken by another session in the intervention' do
      create(:session, intervention: fresh_intervention, variable: 'ra')
      ra = described_class.new(name: 'RA', intervention: fresh_intervention)
      ra.valid?
      expect(ra.variable).to eq('ra_1')
    end

    it 'falls back to "ra_2" when "ra" and "ra_1" are both taken' do
      create(:session, intervention: fresh_intervention, variable: 'ra')
      create(:session, intervention: fresh_intervention, variable: 'ra_1')
      ra = described_class.new(name: 'RA', intervention: fresh_intervention)
      ra.valid?
      expect(ra.variable).to eq('ra_2')
    end

    it 'leaves an explicitly-set variable alone' do
      ra = described_class.new(name: 'RA', variable: 'custom', intervention: fresh_intervention)
      ra.valid?
      expect(ra.variable).to eq('custom')
    end

    it 'isolates the collision check by intervention (same variable in another intervention does not trigger fallback)' do
      other_intervention = create(:intervention)
      create(:session, intervention: other_intervention, variable: 'ra')
      ra = described_class.new(name: 'RA', intervention: fresh_intervention)
      ra.valid?
      expect(ra.variable).to eq('ra')
    end
  end

  describe '#user_session_type' do
    it 'returns UserSession::ResearchAssistant name' do
      expect(ra_session.user_session_type).to eq('UserSession::ResearchAssistant')
    end
  end

  describe '#log_ra_deletion_impact' do
    context 'when there are completed user sessions' do
      let(:participant) { create(:user, :confirmed, :participant) }
      let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }

      before do
        create(:ra_user_session, session: ra_session, user: participant,
                                 user_intervention: user_intervention, finished_at: 1.day.ago)
      end

      it 'logs a warning on destroy naming the completed-session count' do
        allow(Rails.logger).to receive(:warn).and_call_original
        ra_session.destroy
        expect(Rails.logger).to have_received(:warn).with(/RA session .* deleted with 1 completed user sessions/)
      end
    end

    context 'when there are no completed user sessions' do
      it 'does not log a warning on destroy' do
        allow(Rails.logger).to receive(:warn).and_call_original
        ra_session.destroy
        expect(Rails.logger).not_to have_received(:warn).with(/RA session .* deleted/)
      end
    end
  end
end

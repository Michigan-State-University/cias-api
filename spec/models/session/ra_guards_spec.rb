# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session RA guards', type: :model do
  let(:intervention) { create(:intervention) }

  describe '.participant_visible' do
    let!(:classic_session) { create(:session, intervention: intervention) }
    let!(:sms_session) { create(:sms_session, intervention: intervention) }
    let!(:ra_session) { create(:ra_session, intervention: intervention) }

    it 'excludes RA sessions' do
      visible = intervention.sessions.participant_visible
      expect(visible).to include(classic_session, sms_session)
      expect(visible).not_to include(ra_session)
    end
  end

  describe '#position_zero_reserved_for_ra' do
    it 'is invalid for Classic session at position 0' do
      session = build(:session, intervention: intervention, position: 0)
      session.valid?
      expect(session.errors.added?(:position, :reserved_for_ra_session)).to be(true)
    end

    it 'is valid for RA session at position 0' do
      session = build(:ra_session, intervention: intervention, position: 0)
      session.valid?
      expect(session.errors.added?(:position, :reserved_for_ra_session)).to be(false)
    end
  end

  describe '#type_immutable' do
    let!(:classic_session) { create(:session, intervention: intervention) }

    it 'prevents changing type on update' do
      classic_session.type = 'Session::ResearchAssistant'
      expect(classic_session).not_to be_valid
      expect(classic_session.errors.added?(:type, :cannot_change_type)).to be(true)
    end

    it 'does not fire on create' do
      session = build(:session, intervention: intervention)
      session.valid?(:create)
      expect(session.errors[:type]).to be_empty
    end
  end

  describe '#no_branching_to_ra_session' do
    let!(:ra_session) { create(:ra_session, intervention: intervention) }
    let!(:classic_session) { create(:session, intervention: intervention) }
    let!(:other_classic) { create(:session, intervention: intervention) }

    it 'is invalid when Classic session formula targets an RA session' do
      classic_session.formulas = [
        {
          'payload' => '',
          'patterns' => [
            {
              'match' => '=1',
              'target' => [
                { 'type' => 'Session::ResearchAssistant', 'id' => ra_session.id }
              ]
            }
          ]
        }
      ]
      expect(classic_session).not_to be_valid
      expect(classic_session.errors.added?(:formulas, :cannot_branch_to_ra_session)).to be(true)
    end

    it 'is valid when Classic session formula targets another Classic session' do
      classic_session.formulas = [
        {
          'payload' => '',
          'patterns' => [
            {
              'match' => '=1',
              'target' => [
                { 'type' => 'Session::Classic', 'id' => other_classic.id }
              ]
            }
          ]
        }
      ]
      expect(classic_session).to be_valid
    end
  end

  describe '#next_session' do
    let!(:ra_session) { create(:ra_session, intervention: intervention) }
    let!(:session1) { create(:session, intervention: intervention, position: 1) }
    let!(:session2) { create(:session, intervention: intervention, position: 2) }

    it 'skips RA sessions when finding next' do
      expect(session1.next_session).to eq(session2)
    end

    it 'returns nil when only RA sessions remain (last_session? is true)' do
      session2.destroy
      expect(session1.last_session?).to be(true)
    end
  end
end

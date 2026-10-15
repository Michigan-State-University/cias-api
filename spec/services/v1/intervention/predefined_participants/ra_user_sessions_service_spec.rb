# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::PredefinedParticipants::RaUserSessionsService do
  let(:intervention) { create(:intervention, :published) }
  let!(:ra_session) { create(:ra_session, intervention: intervention) }
  let(:participant) { create(:user, :confirmed, :predefined_participant) }
  let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
  let!(:ra_user_session) do
    create(:ra_user_session, session: ra_session, user: participant, user_intervention: user_intervention)
  end

  it 'indexes RA user sessions by user id' do
    expect(described_class.call(intervention, [participant.id])).to eq(participant.id => ra_user_session)
  end

  it 'returns an empty hash when no user ids are given' do
    expect(described_class.call(intervention, [])).to eq({})
  end

  it 'returns an empty hash when the intervention has no RA session' do
    ra_session.destroy
    expect(described_class.call(intervention, [participant.id])).to eq({})
  end

  it 'omits participants without an RA user session' do
    other_participant = create(:user, :confirmed, :predefined_participant)
    result = described_class.call(intervention, [participant.id, other_participant.id])
    expect(result.keys).to contain_exactly(participant.id)
  end
end

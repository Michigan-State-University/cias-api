# frozen_string_literal: true

RSpec.describe V1::UserSessions::CreateService do
  subject { described_class.call(session_id, user_id, health_clinic_id) }

  let(:user) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, :multiple_times, intervention: intervention) }
  let(:health_clinic_id) { nil }
  let(:user_id) { user.id }
  let(:session_id) { session.id }

  # before do
  #   allow(UserSession).to receive(:new).and_return(true)
  # end

  context 'when user session and user intervention do not exist' do
    it 'create user intervention' do
      expect { subject }.to change(UserIntervention, :count).by(1)
    end

    it 'instantiate user session' do
      expect(subject).to be_instance_of(UserSession::Classic)
    end
  end

  context 'when user intervention exist' do
    let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

    it 'return existing user intervention' do
      expect { subject }.to change(UserIntervention, :count).by(0)
    end

    it 'instantiate user session' do
      expect(subject).to be_instance_of(UserSession::Classic)
    end
  end
end

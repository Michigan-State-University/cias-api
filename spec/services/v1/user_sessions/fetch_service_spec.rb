# frozen_string_literal: true

RSpec.describe V1::UserSessions::FetchService do
  subject { described_class.call(session_id, user_id, health_clinic_id) }

  let(:user) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, :multiple_times, intervention: intervention) }
  let(:health_clinic_id) { nil }
  let(:user_id) { user.id }
  let(:session_id) { session.id }
  let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

  context 'with existing user_session' do
    let!(:user_session) { create(:user_session, user_intervention: user_intervention, user: user, session: session) }

    it 'return correct user_session' do
      expect(subject&.id).to eq user_session.id
    end
  end

  context 'without existing user_session' do
    it 'return exception' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'with existing user_intervention but without user_session' do
    before do
      user_intervention
    end

    it 'return exception' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when user wants to fetch scheduled session' do
    before do
      UserSession.create(session_id: session_id, user_intervention_id: user_intervention.id, user: user, scheduled_at: 10.days.from_now)
    end

    it 'return exception' do
      expect { subject }.to raise_error(CanCan::AccessDenied)
    end
  end
end

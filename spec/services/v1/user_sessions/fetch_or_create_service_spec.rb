# frozen_string_literal: true

RSpec.describe V1::UserSessions::FetchOrCreateService do
  subject { described_class.call(session_id, user_id, health_clinic_id) }

  context 'multiple fill session' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:intervention) { create(:intervention) }
    let(:session) { create(:session, :multiple_times, intervention: intervention) }
    let(:health_clinic_id) { nil }
    let(:user_id) { user.id }
    let(:session_id) { session.id }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

    context 'there is unfinished existing user session' do
      let!(:user_session) { create(:user_session, session: session, user: user, user_intervention: user_intervention, finished_at: nil) }

      it 'returns existing user session' do
        expect(subject&.id).to eq user_session.id
      end
    end

    context 'there are no present user sessions' do
      it 'returns new user session' do
        expect(subject).not_to be_nil
      end
    end
  end
end

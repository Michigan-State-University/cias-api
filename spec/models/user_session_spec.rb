# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSession, type: :model do
  context 'UserSession' do
    subject { create(:session) }

    it { should belong_to(:intervention) }
    it { should have_many(:questions) }
    it { should be_valid }
  end

  xcontext 'proper alter_schedule result' do
    let(:intervention) { create(:intervention) }
    let(:user) { create(:user, :participant) }
    let(:sessions) do
      sessions = create_list(:session, 3, intervention_id: intervention.id, schedule: 'days_after_fill', schedule_payload: 7)
      first_inter = sessions.first
      first_inter.update(schedule: nil, schedule_payload: nil)
      sessions
    end
    let(:user_session_1) { create(:user_session, session_id: sessions.first.id, user_id: user.id) }
    let(:user_session_2) { create(:user_session, session_id: sessions.second.id, user_id: user.id) }

    it 'calc date for next session properly' do
      sessions
      user_session_1
      user_session_2
      user_session_1.update(submitted_at: Date.current)
      user_session_2.reload

      expect(user_session_2.schedule_at).to eq(Date.current + 7)
    end
  end
end

# frozen_string_literal: true

RSpec.describe AfterFinishUserSessionJob, type: :job do
  let(:intervention) { create(:intervention, hfhs_access: true) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user_intervention) { create(:user_intervention, intervention: intervention) }
  let(:user_session) { create(:user_session, session: session, user_intervention: user_intervention) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(V1::GeneratedReports::GenerateUserSessionReports).to receive(:call)
  end

  context 'when the session was completed' do
    it 'pushes the answers to Henry Ford' do
      expect { described_class.new.perform(user_session.id, intervention) }
        .to have_enqueued_job(Hfhs::SendAnswersJob).with(user_session.id)
    end
  end

  context 'when the session was closed by an inactivity timeout' do
    it 'generates the reports' do
      expect(V1::GeneratedReports::GenerateUserSessionReports).to receive(:call)

      described_class.new.perform(user_session.id, intervention, 'inactivity_timeout')
    end

    it 'does not push the answers to Henry Ford' do
      expect { described_class.new.perform(user_session.id, intervention, 'inactivity_timeout') }
        .not_to have_enqueued_job(Hfhs::SendAnswersJob)
    end
  end
end

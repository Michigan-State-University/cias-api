# frozen_string_literal: true

RSpec.describe Hfhs::SendAnswersJob, type: :job do
  subject(:perform_job) { described_class.perform_now(user_session.id) }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let_it_be(:session) { create(:session, intervention: intervention) }

  let(:api) { instance_double(Api::Hfhs, send_answers: true, send_reports: true) }
  let(:user_session) { create(:user_session, user: user, session: session) }

  before { allow(Api::Hfhs).to receive(:new).and_return(api) }

  context 'with an ordinary participant' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'sends the answers and the reports' do
      perform_job

      expect(api).to have_received(:send_answers).with(user_session.id)
      expect(api).to have_received(:send_reports).with(user_session.id)
    end
  end

  # The one effect of a fill that cannot be undone: the purge deletes our copy of what was sent but
  # cannot recall the message.
  context 'with a test participant' do
    let(:user) do
      create(:user, :confirmed, :guest).tap do |guest|
        guest.update!(test_run: true, test_run_intervention_id: intervention.id)
      end
    end

    it 'transmits nothing to HFHS' do
      perform_job

      expect(api).not_to have_received(:send_answers)
      expect(api).not_to have_received(:send_reports)
    end

    it 'records why it withheld the transmission' do
      allow(Rails.logger).to receive(:warn)

      perform_job

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including('skipped HFHS transmission for a test run', "user_id=#{user.id}")
      )
    end
  end

  context 'when the session has already been purged' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'transmits nothing and does not raise' do
      id = user_session.id
      user_session.destroy!

      expect { described_class.perform_now(id) }.not_to raise_error
      expect(api).not_to have_received(:send_answers)
    end
  end
end

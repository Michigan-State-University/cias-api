# frozen_string_literal: true

RSpec.describe TestParticipants::PurgeTestParticipantsJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  subject(:perform_job) { described_class.perform_now(guest.id) }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let_it_be(:session) { create(:session, intervention: intervention) }

  # Not `let_it_be`: the subject destroys all of it, so it cannot be memoised across examples.
  let(:guest) do
    create(:user, :confirmed, :guest).tap do |user|
      user.update!(test_run: true, test_run_intervention_id: intervention.id, test_run_marked_by_id: researcher.id)
    end
  end

  let(:user_intervention) { create(:user_intervention, user: guest, intervention: intervention) }
  let(:user_session) { create(:user_session, user: guest, session: session, user_intervention: user_intervention) }
  let!(:answer) { create(:answer_single, user_session: user_session) }

  describe '#perform' do
    context 'with a marked test participant' do
      it 'purges the participant through PurgeService' do
        expect(V1::Intervention::TestParticipants::PurgeService).to receive(:call).with(guest.id).and_call_original

        perform_job
      end

      it 'removes the participant and the fill it produced' do
        perform_job

        expect(User.where(id: guest.id)).to be_empty
        expect(UserSession.where(id: user_session.id)).to be_empty
        expect(Answer.where(id: answer.id)).to be_empty
      end
    end

    context 'when the participant was already purged' do
      it 'is a clean no-op' do
        guest_id = guest.id
        perform_job

        result = nil
        expect { result = described_class.perform_now(guest_id) }.not_to have_enqueued_job(described_class)
        expect(result).to be_a(V1::Intervention::TestParticipants::PurgeService::Result)
      end

      it 'reports the refusal rather than purging' do
        perform_job

        expect(described_class.perform_now(guest.id).skip_reason).to eq(:already_purged)
      end
    end

    context 'when the marker was cleared between scheduling and execution' do
      it 'leaves the participant and their data alone' do
        guest.update!(test_run: false)

        expect { perform_job }.not_to change(UserSession, :count)
        expect(User.where(id: guest.id)).to be_present
        expect(perform_job.skip_reason).to eq(:not_marked)
      end
    end

    context 'when the marker carries no intervention' do
      it 'refuses rather than purging anything' do
        guest.update!(test_run_intervention_id: nil)

        expect { perform_job }.not_to change(UserSession, :count)
        expect(perform_job.skip_reason).to eq(:unscoped_marker)
      end
    end

    context 'when the guest also filled a different intervention' do
      let_it_be(:other_researcher) { create(:user, :confirmed, :researcher) }
      let_it_be(:other_intervention) do
        create(:intervention, user: other_researcher, status: :published, shared_to: :anyone)
      end
      let_it_be(:other_session) { create(:session, intervention: other_intervention) }

      let(:other_user_intervention) { create(:user_intervention, user: guest, intervention: other_intervention) }
      let!(:other_user_session) do
        create(:user_session, user: guest, session: other_session, user_intervention: other_user_intervention)
      end
      let!(:other_answer) { create(:answer_single, user_session: other_user_session) }

      it "destroys only the marked intervention's fill" do
        perform_job

        expect(UserSession.where(id: user_session.id)).to be_empty
        expect(Answer.where(id: answer.id)).to be_empty
        expect(UserSession.where(id: other_user_session.id)).to be_present
        expect(Answer.where(id: other_answer.id)).to be_present
      end

      it 'keeps the guest account and releases the marker so later sweeps stop selecting them' do
        perform_job

        expect(guest.reload.test_run).to be(false)
        expect(guest.test_run_intervention_id).to be_nil
      end
    end
  end

  # The queue name is duplicated in `config/sidekiq.yml`; a mismatch enqueues into a queue no worker polls.
  describe 'the queue' do
    it 'runs on its own queue, not the shared default' do
      expect(described_class.new.queue_name).to eq('test_participant_purge')
    end

    it 'is a queue Sidekiq is configured to poll, at a lower weight than default' do
      config = YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol], aliases: true)
      queues = config[:queues]
      entry = queues.find { |name, _weight| name == 'test_participant_purge' }
      default_weight = queues.find { |name, _weight| name == 'default' }.last

      expect(entry).to be_present
      expect(entry.last).to be < default_weight
    end

    it 'enqueues onto that queue' do
      expect { described_class.perform_later(guest.id) }
        .to have_enqueued_job(described_class).on_queue('test_participant_purge')
    end
  end

  # Against the job's own constant — that the marker path applies it is `spec/services/v1/test_runs/mark_guest_spec.rb`.
  describe 'the delayed-enqueue contract' do
    it 'can be scheduled to fire one retention window after marking' do
      freeze_time do
        expect { described_class.set(wait_until: described_class::RETENTION_WINDOW.from_now).perform_later(guest.id) }
          .to have_enqueued_job(described_class).with(guest.id).at(described_class::RETENTION_WINDOW.from_now)
      end
    end

    it 'keeps the retention window fixed at 24 hours (assumption A3 — not configurable)' do
      expect(described_class::RETENTION_WINDOW).to eq(24.hours)
    end
  end
end

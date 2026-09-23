# frozen_string_literal: true

RSpec.describe V1::Intervention::TestParticipants::ReconcileStrandedPurges do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  subject(:reconcile) { described_class.call }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let_it_be(:session) { create(:session, intervention: intervention) }

  # Stamped directly rather than by marking a guest: a real marker also enqueues the job, which is
  # exactly the stranding these examples need to *not* have happened.
  def strand(user, scheduled_at: 2.hours.ago, intervention_id: intervention.id)
    user.update!(test_run: true, test_run_intervention_id: intervention_id, purge_scheduled_at: scheduled_at)
    user
  end

  let(:guest) { strand(create(:user, :confirmed, :guest)) }
  let(:user_intervention) { create(:user_intervention, user: guest, intervention: intervention) }
  let!(:user_session) { create(:user_session, user: guest, session: session, user_intervention: user_intervention) }

  describe 'finding and re-enqueuing' do
    it 're-enqueues a purge that fell due and never ran' do
      expect { reconcile }
        .to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)
        .with(guest.id)
        .on_queue('test_participant_purge')
    end

    it 'reports what it found and what it enqueued' do
      result = reconcile

      expect(result.found).to eq(1)
      expect(result.enqueued).to eq(1)
      expect(result).not_to be_dry_run
    end

    it 'enqueues the job without a delay — these purges are already overdue' do
      freeze_time do
        expect { reconcile }
          .to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob).at(:no_wait)
      end
    end

    it 'does not re-enqueue a purge that is not due yet' do
      guest.update!(purge_scheduled_at: 2.hours.from_now)

      expect { reconcile }.not_to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)
      expect(reconcile.found).to eq(0)
    end

    it 'does not re-enqueue a participant whose marker was cleared' do
      guest.update!(test_run: false)

      expect { reconcile }.not_to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)
    end

    # The hard precondition from the phase-1 review: `test_run` is user-level while the link that
    # sets it is minted per intervention, so an unscopable marker must never be handed to a job that
    # destroys data. Removing `where.not(test_run_intervention_id: nil)` from the query fails here.
    it 'does not re-enqueue a marker that carries no intervention' do
      guest.update!(test_run_intervention_id: nil)

      expect { reconcile }.not_to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)
    end
  end

  describe 'the recovery it exists for' do
    # The whole point of item 2.11: the 24h job lived in Redis, Redis was lost, nothing fired. The
    # user is still marked and still stamped, so the reconciler finds it and the purge completes.
    it 'completes a purge that the lost scheduled job would have done' do
      perform_enqueued_jobs { reconcile }

      expect(User.where(id: guest.id)).to be_empty
      expect(UserSession.where(id: user_session.id)).to be_empty
    end
  end

  describe 'running it twice' do
    it 'does not raise, and does not purge twice' do
      guest_id = guest.id
      perform_enqueued_jobs { reconcile }

      expect { perform_enqueued_jobs { described_class.call } }.not_to raise_error
      expect(described_class.call.found).to eq(0)
      expect(User.where(id: guest_id)).to be_empty
    end

    # Two overlapping runs before either job executes: the duplicate is harmless because
    # `PurgeService` re-reads the marker under a row lock and refuses the second pass.
    it 'is harmless when the same candidate is enqueued twice before either job runs' do
      described_class.call
      described_class.call

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(User.where(id: guest.id)).to be_empty
    end

    # Re-stamping or clearing `purge_scheduled_at` would make the reconciler look tidier and destroy
    # the only evidence that a purge was owed and missed. It is also a production write of a column
    # this build must not write.
    it 'leaves purge_scheduled_at untouched' do
      expect { reconcile }.not_to change { guest.reload.purge_scheduled_at }
    end
  end

  describe 'dry run' do
    it 'reports the candidates without enqueuing anything' do
      result = nil

      expect { result = described_class.call(dry_run: true) }
        .not_to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)

      expect(result.found).to eq(1)
      expect(result.enqueued).to eq(0)
      expect(result).to be_dry_run
    end
  end

  describe 'batching' do
    it 'enqueues every candidate when there are more than one batch of them' do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      second_guest = strand(create(:user, :confirmed, :guest))

      expect { reconcile }
        .to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob).with(guest.id)
        .and have_enqueued_job(TestParticipants::PurgeTestParticipantsJob).with(second_guest.id)
    end
  end

  describe 'the per-run ceiling' do
    it 'refuses a run larger than the ceiling and enqueues nothing' do
      2.times { strand(create(:user, :confirmed, :guest)) }

      result = nil
      expect { result = described_class.call(max_purges: 2) }
        .not_to have_enqueued_job(TestParticipants::PurgeTestParticipantsJob)

      expect(result).to be_refused
      expect(result.found).to eq(3)
      expect(result.enqueued).to eq(0)
    end

    it 'enqueues normally at or below the ceiling' do
      expect(described_class.call(max_purges: 1).enqueued).to eq(1)
    end

    # A dry run destroys nothing, and a truncated preview would hide the scale the operator needs.
    it 'never refuses a dry run' do
      2.times { strand(create(:user, :confirmed, :guest)) }

      expect(described_class.call(dry_run: true, max_purges: 1)).not_to be_refused
    end

    it 'reports the candidate ids so a preview can be inspected and a lost run reconstructed' do
      expect(described_class.call(dry_run: true).candidate_ids).to contain_exactly(guest.id)
    end
  end
end

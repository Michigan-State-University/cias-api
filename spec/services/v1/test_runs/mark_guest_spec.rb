# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::TestRuns::MarkGuest do
  subject(:mark) { described_class.call(user, intervention.id, token) }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }

  let(:user) { create(:user, :confirmed, :guest) }
  let(:minted) { V1::TestRuns::LinkToken.mint(intervention.id, researcher.id) }
  let(:token) { minted.token }

  context 'with a valid token' do
    it 'marks the guest as a test run' do
      expect(mark).to be(true)
      expect(user.reload.test_run).to be(true)
    end

    it 'records the intervention the marker covers' do
      mark

      expect(user.reload.test_run_intervention_id).to eq(intervention.id)
    end

    it 'records the researcher whose link did the marking' do
      mark

      expect(user.reload.test_run_marked_by_id).to eq(researcher.id)
    end
  end

  context 'with no token' do
    let(:token) { nil }

    it 'leaves the guest unmarked' do
      expect(mark).to be(false)
      expect(user.reload.test_run).to be(false)
    end
  end

  context 'with an expired token' do
    it 'leaves the guest unmarked' do
      token = minted.token

      Timecop.travel(V1::TestRuns::LinkToken.ttl.from_now + 1.minute) do
        expect(described_class.call(user, intervention.id, token)).to be(false)
      end

      expect(user.reload.test_run).to be(false)
    end
  end

  context 'with a token minted for another intervention' do
    let(:minted) { V1::TestRuns::LinkToken.mint(SecureRandom.uuid, researcher.id) }

    it 'leaves the guest unmarked' do
      expect(mark).to be(false)
      expect(user.reload.test_run).to be(false)
    end
  end

  # D8, revised: the link is a time-boxed capability with no ceiling on it. A one-shot nonce, and
  # then a cap of five, both did the same thing — they moved the silent-failure cliff. The first
  # fill past the cliff is recorded as a permanent, un-purgeable real participant, which is the
  # exact pollution this feature exists to prevent. The TTL, the single intervention and the
  # authorization check at mint time are what bound the link.
  context 'when the same token is used again' do
    it 'marks a second guest too' do
      first_guest = create(:user, :confirmed, :guest)
      second_guest = create(:user, :confirmed, :guest)

      expect(described_class.call(first_guest, intervention.id, token)).to be(true)
      expect(described_class.call(second_guest, intervention.id, token)).to be(true)

      expect(first_guest.reload.test_run).to be(true)
      expect(second_guest.reload.test_run).to be(true)
    end

    it 'keeps marking well past the ceiling that used to apply' do
      guests = Array.new(7) { create(:user, :confirmed, :guest) }

      results = guests.map { |guest| described_class.call(guest, intervention.id, token) }

      expect(results).to all(be(true))
      expect(guests.map { |guest| guest.reload.test_run }).to all(be(true))
    end
  end

  context 'when the user is not a guest' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'refuses to mark a registered participant' do
      expect(mark).to be(false)
      expect(user.reload.test_run).to be(false)
    end
  end

  # A guest older than the token's own lifetime cannot be the guest this fill just created: it is a
  # kiosk, a shared browser or a forwarded link, and it may already hold real participant data that
  # the eventual purge must never touch.
  context 'when the guest is older than the token lifetime' do
    let(:user) do
      create(:user, :confirmed, :guest).tap do |guest|
        guest.update_column(:created_at, V1::TestRuns::LinkToken.ttl.ago - 1.day)
      end
    end

    before { create(:user_session, user: user, session: create(:session, intervention: intervention)) }

    it 'refuses to mark a pre-existing guest that already holds fills' do
      expect(mark).to be(false)
      expect(user.reload.test_run).to be(false)
    end

    it 'still marks the fresh guest the link was meant for' do
      mark
      fresh_guest = create(:user, :confirmed, :guest)

      expect(described_class.call(fresh_guest, intervention.id, token)).to be(true)
    end
  end

  context 'when persisting the marker blows up' do
    before { allow(user).to receive(:update!).and_raise(ActiveRecord::StatementInvalid) }

    it 'swallows the error so the fill can continue' do
      expect(mark).to be(false)
      expect(user.reload.test_run).to be(false)
    end

    # A write that blows up costs the link nothing — there is no counter to put back.
    it 'leaves the link usable for the next guest' do
      mark
      other_guest = create(:user, :confirmed, :guest)

      expect(described_class.call(other_guest, intervention.id, token)).to be(true)
      expect(other_guest.reload.test_run).to be(true)
    end
  end

  # Work item 2.5 — the marker and its fuse are a single act. A marker with no scheduled purge is a
  # test fill that pollutes the charts forever (decision D6 removed the manual purge), and a purge
  # scheduled for a fill that was *not* marked would delete a real participant. So every example
  # below pins both halves together: a successful mark schedules the deletion and records when, and
  # a refused mark does neither.
  describe 'the scheduled purge' do
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    let(:purge_job) { TestParticipants::PurgeTestParticipantsJob }

    shared_examples 'a refused mark' do
      it 'schedules no purge' do
        expect { mark }.not_to have_enqueued_job(purge_job)
      end

      it 'leaves purge_scheduled_at unset' do
        mark

        expect(user.reload.purge_scheduled_at).to be_nil
      end
    end

    context 'when the guest is marked' do
      it 'enqueues the purge one retention window out' do
        freeze_time do
          expect { mark }
            .to have_enqueued_job(purge_job)
            .with(user.id)
            .at(purge_job::RETENTION_WINDOW.from_now)
        end
      end

      it 'records that same instant in purge_scheduled_at' do
        freeze_time do
          mark

          expect(user.reload.purge_scheduled_at).to eq(purge_job::RETENTION_WINDOW.from_now)
        end
      end

      # Names no duration: `StrandedPurgesQuery` treats the stamp as the firing time, so a stamp
      # later than the job hides a stranding and an earlier one re-enqueues a live purge. Note this
      # runs under `freeze_time`, so it pins stamp == enqueued-at but cannot by itself distinguish
      # `wait_until:` from a `wait:` that re-evaluates the clock.
      it 'schedules the job for exactly the instant it stamped' do
        freeze_time do
          mark
          stamped = user.reload.purge_scheduled_at

          # `.at(nil)` degrades into "no scheduling constraint", so an unstamped row would make the
          # comparison below pass while proving nothing.
          expect(stamped).to be_present
          expect(purge_job).to have_been_enqueued.with(user.id).at(stamped)
        end
      end

      it 'enqueues onto the dedicated purge queue, not default' do
        expect { mark }.to have_enqueued_job(purge_job).on_queue('test_participant_purge')
      end
    end

    context 'with no token' do
      let(:token) { nil }

      it_behaves_like 'a refused mark'
    end

    context 'with a token minted for another intervention' do
      let(:minted) { V1::TestRuns::LinkToken.mint(SecureRandom.uuid, researcher.id) }

      it_behaves_like 'a refused mark'
    end

    context 'when the user is not a guest' do
      let(:user) { create(:user, :confirmed, :participant) }

      it_behaves_like 'a refused mark'
    end

    context 'when the guest is older than the token lifetime' do
      let(:user) do
        create(:user, :confirmed, :guest).tap do |guest|
          guest.update_column(:created_at, V1::TestRuns::LinkToken.ttl.ago - 1.day)
        end
      end

      it_behaves_like 'a refused mark'
    end

    context 'with an expired token' do
      it 'schedules nothing and stamps nothing' do
        token = minted.token

        Timecop.travel(V1::TestRuns::LinkToken.ttl.from_now + 1.minute) do
          expect { described_class.call(user, intervention.id, token) }.not_to have_enqueued_job(purge_job)
        end

        expect(user.reload.purge_scheduled_at).to be_nil
      end
    end

    # The ordering guard. The enqueue follows the write, so a marker that never landed cannot leave
    # a deletion scheduled against the row behind it.
    context 'when persisting the marker blows up' do
      before { allow(user).to receive(:update!).and_raise(ActiveRecord::StatementInvalid) }

      it 'schedules no purge, because the enqueue follows the write' do
        expect { mark }.not_to have_enqueued_job(purge_job)
      end

      it 'leaves the row unmarked and unstamped' do
        mark

        expect(user.reload.test_run).to be(false)
        expect(user.reload.purge_scheduled_at).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe TestParticipants::StrandedPurgesQuery do
  subject(:candidates) { described_class.call }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }

  def build_guest(attributes)
    create(:user, :confirmed, :guest).tap { |user| user.update!(attributes) }
  end

  let!(:stranded) do
    build_guest(test_run: true, test_run_intervention_id: intervention.id, purge_scheduled_at: 2.hours.ago)
  end

  it 'finds a marked participant whose purge fell due and did not happen' do
    expect(candidates).to contain_exactly(stranded)
  end

  it 'ignores a participant whose purge is not due yet' do
    build_guest(test_run: true, test_run_intervention_id: intervention.id, purge_scheduled_at: 2.hours.from_now)

    expect(candidates).to contain_exactly(stranded)
  end

  it 'ignores a participant that was never scheduled' do
    build_guest(test_run: true, test_run_intervention_id: intervention.id, purge_scheduled_at: nil)

    expect(candidates).to contain_exactly(stranded)
  end

  # The purge either destroys the shell or releases the marker; either way the record stops being a
  # candidate, which is what makes re-running the reconciler safe.
  it 'ignores a participant whose marker was released' do
    build_guest(test_run: false, test_run_intervention_id: nil, purge_scheduled_at: 2.hours.ago)

    expect(candidates).to contain_exactly(stranded)
  end

  it 'ignores an ordinary participant that was never marked' do
    create(:user, :confirmed, :participant)

    expect(candidates).to contain_exactly(stranded)
  end

  # The hard precondition from the phase-1 review, enforced at the point candidates are chosen.
  # `test_run` is user-level while the link that sets it is minted per intervention, so a marker
  # with no intervention cannot be scoped to one and must never reach a destructive job — a bare
  # `User.where(test_run: true)` sweep is what this clause exists to prevent.
  it 'ignores a marker that carries no intervention, because it cannot be scoped' do
    build_guest(test_run: true, test_run_intervention_id: nil, purge_scheduled_at: 2.hours.ago)

    expect(candidates).to contain_exactly(stranded)
  end

  it 'evaluates the due-by boundary against the time it is given' do
    expect(described_class.call(3.hours.ago)).to be_empty
    expect(described_class.call(1.hour.ago)).to contain_exactly(stranded)
  end
end

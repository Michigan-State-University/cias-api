# frozen_string_literal: true

# Stale = 3 hours and fresh = 1 minute, so the examples hold for any reasonable staleness threshold.
RSpec.describe 'PredefinedParticipants::StrandedCampaignsQuery' do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.utc(2026, 11, 2, 12, 0, 0) }
  let(:query) { PredefinedParticipants::StrandedCampaignsQuery }
  let(:result_ids) { query.call.map(&:id) }

  before { travel_to now }

  def campaign(status: 'scheduled', kind: 'invitation', scheduled_at: now - 1.hour, updated_at: now - 3.hours, parent: nil)
    record = create(:pdp_sms_campaign, :scheduled, status: status, kind: kind, scheduled_at: scheduled_at, parent_campaign: parent,
                                                   days_after: (kind == 'scheduled_reminder' ? 3 : nil),
                                                   intervention: parent&.intervention || create(:intervention, :published))
    record.update_columns(updated_at: updated_at)
    record
  end

  describe 'what is swept up' do
    it 'a scheduled campaign that is due and has been silent for hours' do
      stranded = campaign(status: 'scheduled')
      expect(result_ids).to include(stranded.id)
    end

    it 'a sending campaign that is due and has been silent for hours (retries exhausted / lost run)' do
      stranded = campaign(status: 'sending')
      expect(result_ids).to include(stranded.id)
    end

    it 'covers all three kinds' do
      invitation = campaign(kind: 'invitation')
      manual = campaign(kind: 'manual_reminder')
      parent = campaign(kind: 'invitation', status: 'sent')
      child = campaign(kind: 'scheduled_reminder', parent: parent)

      expect(result_ids).to include(invitation.id, manual.id, child.id)
    end

    it 'a campaign whose scheduled_at is exactly now (the boundary is inclusive)' do
      due_now = campaign(scheduled_at: now)
      expect(result_ids).to include(due_now.id)
    end
  end

  describe 'what is NOT swept up' do
    it 'a campaign legitimately waiting for a future scheduled_at, however old its updated_at' do
      waiting = campaign(scheduled_at: now + 5.days, updated_at: now - 4.days)
      expect(result_ids).not_to include(waiting.id)
    end

    it 'a child reminder waiting X days (status scheduled, updated_at untouched since creation)' do
      parent = campaign(kind: 'invitation', status: 'sent')
      child = campaign(kind: 'scheduled_reminder', parent: parent, scheduled_at: now + 3.days, updated_at: now - 1.day)
      expect(result_ids).not_to include(child.id)
    end

    it 'a due campaign that was touched a minute ago (a run is still alive)' do
      alive = campaign(status: 'sending', updated_at: now - 1.minute)
      expect(result_ids).not_to include(alive.id)
    end

    %w[sent failed cancelled skipped].each do |status|
      it "a #{status} campaign, however stale" do
        closed = campaign(status: status)
        expect(result_ids).not_to include(closed.id)
      end
    end
  end

  it 'returns nothing when no campaign is stranded' do
    campaign(status: 'sent')
    campaign(kind: 'manual_reminder', status: 'scheduled', scheduled_at: now + 1.day)

    expect(result_ids).to be_empty
  end

  it 'returns only the stranded ones from a mixed set' do
    stranded = [campaign(status: 'scheduled'), campaign(status: 'sending')]
    campaign(scheduled_at: now + 1.day)
    campaign(status: 'sent')
    campaign(updated_at: now - 1.minute)

    expect(result_ids).to match_array(stranded.map(&:id))
  end

  it 'is a relation-like result that can be counted and batched without loading every row' do
    campaign
    expect(query.call).to respond_to(:count)
    expect(query.call.count).to eq(1)
  end
end

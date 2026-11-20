# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::SmsLinks::VerifyService do
  subject(:call) { described_class.call(sms_links_user) }

  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, session: session) }
  let(:sms_link) { create(:sms_link, sms_plan: sms_plan, session: session, url: 'https://example.test/canary-target', variable: 'canary_link') }
  let(:user) { create(:user, :confirmed) }
  let(:sms_links_user) { create(:sms_links_user, sms_link: sms_link, user: user) }
  let(:now) { Time.zone.parse('2026-10-30 12:00:00') }

  describe 'click tracking' do
    it 'appends one timestamp for a single entry' do
      expect { call }.to change { sms_links_user.reload.entered_timestamps.size }.from(0).to(1)
    end

    it 'persists the timestamp in the stored format' do
      travel_to(now) { call }
      expect(sms_links_user.reload.entered_timestamps).to eq([now.strftime('%Y-%m-%d %H:%M:%S UTC')])
    end

    it 'accumulates one entry per click instead of overwriting' do
      travel_to(now) { described_class.call(sms_links_user) }
      travel_to(now + 1.hour) { described_class.call(sms_links_user) }

      expect(sms_links_user.reload.entered_timestamps).to eq(
        [now.strftime('%Y-%m-%d %H:%M:%S UTC'), (now + 1.hour).strftime('%Y-%m-%d %H:%M:%S UTC')]
      )
    end

    it 'does not touch the timestamps of another participant on the same link' do
      other = create(:sms_links_user, sms_link: sms_link, user: create(:user, :confirmed))
      call
      expect(other.reload.entered_timestamps).to be_empty
    end

    it 'does not touch the timestamps of the same participant on another link' do
      other_link = create(:sms_link, sms_plan: sms_plan, session: session, variable: 'other_canary_link')
      other = create(:sms_links_user, sms_link: other_link, user: user)
      call
      expect(other.reload.entered_timestamps).to be_empty
    end
  end

  describe 'redirect url' do
    it 'returns the url of the link' do
      expect(call).to eq('https://example.test/canary-target')
    end

    context 'when the link belongs to a campaign instead of a plan' do
      let(:campaign) { create(:pdp_sms_campaign, intervention: intervention) }
      let(:sms_link) { create(:pdp_campaign_sms_link, campaign: campaign) }

      it 'returns the url although sms_plan and session are nil' do
        expect([sms_link.sms_plan_id, sms_link.session_id]).to eq([nil, nil])
        expect(call).to eq('https://example.test/canary-target')
      end

      it 'records the click' do
        expect { call }.to change { sms_links_user.reload.entered_timestamps.size }.from(0).to(1)
      end
    end

    context 'when the participant is a predefined participant and the url points at the intervention' do
      let(:user) { create(:user, :confirmed, :predefined_participant) }
      let(:sms_link) do
        create(:sms_link, sms_plan: sms_plan, session: session, variable: 'canary_link',
                          url: "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/sessions/#{session.id}/fill")
      end

      it 'appends the pid of that participant' do
        expect(call).to include("pid=#{user.predefined_user_parameter.slug}")
      end

      it 'still records the click' do
        expect { call }.to change { sms_links_user.reload.entered_timestamps.size }.from(0).to(1)
      end
    end
  end

  describe 'unknown slug' do
    it 'returns nil instead of raising when there is no matching row' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'creates no SmsLinksUser row' do
      sms_links_user
      expect { described_class.call(nil) }.not_to change(SmsLinksUser, :count)
    end
  end
end

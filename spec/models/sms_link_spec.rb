# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsLink, type: :model do
  let(:campaign_b) { create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder') }
  let(:campaign_a) { create(:pdp_sms_campaign, intervention: intervention) }
  let(:intervention) { create(:intervention, :published) }
  let(:campaign) { create(:pdp_sms_campaign) }

  describe 'associations' do
    it { should belong_to(:sms_plan).optional }
    it { should belong_to(:session).optional }
    it { should belong_to(:variant).optional }
  end

  describe '#set_derived_ids' do
    context 'when only variant_id is provided (no sms_plan_id / session_id from caller)' do
      let(:sms_plan) { create(:sms_plan) }
      let(:variant)  { create(:sms_plan_variant, sms_plan: sms_plan) }

      it 'derives sms_plan_id from the variant' do
        sms_link = described_class.create!(variant: variant, url: 'https://test.com', link_type: 'website', variable: 'v1')
        expect(sms_link.sms_plan_id).to eq(sms_plan.id)
      end

      it 'derives session_id from the variant\'s sms_plan' do
        sms_link = described_class.create!(variant: variant, url: 'https://test.com', link_type: 'website', variable: 'v1')
        expect(sms_link.session_id).to eq(sms_plan.session_id)
      end
    end
  end

  describe 'uniqueness validation' do
    let(:sms_plan) { create(:sms_plan) }

    context 'no-formula (variant_id nil)' do
      before { create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, variable: 'promo') }

      it 'rejects a duplicate variable in the same plan' do
        duplicate = described_class.new(sms_plan: sms_plan, session: sms_plan.session,
                                        url: 'https://x.com', link_type: 'website', variable: 'promo')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:variable]).to be_present
      end

      it 'allows the same variable name in a different plan' do
        other_plan = create(:sms_plan, session: sms_plan.session)
        sibling = described_class.new(sms_plan: other_plan, session: sms_plan.session,
                                      url: 'https://x.com', link_type: 'website', variable: 'promo')
        expect(sibling).to be_valid
      end
    end

    context 'formula (variant_id present)' do
      let(:variant_a) { create(:sms_plan_variant, sms_plan: sms_plan) }
      let(:variant_b) { create(:sms_plan_variant, sms_plan: sms_plan) }

      before { create(:sms_link, variant: variant_a, sms_plan: sms_plan, session: sms_plan.session, variable: 'offer') }

      it 'rejects a duplicate variable in the same variant' do
        duplicate = described_class.new(variant: variant_a, sms_plan: sms_plan, session: sms_plan.session,
                                        url: 'https://x.com', link_type: 'website', variable: 'offer')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:variable]).to be_present
      end

      it 'allows the same variable name in a different variant' do
        cross_variant = described_class.new(variant: variant_b, sms_plan: sms_plan, session: sms_plan.session,
                                            url: 'https://x.com', link_type: 'website', variable: 'offer')
        expect(cross_variant).to be_valid
      end
    end

    context 'mixed modes' do
      let(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }

      before { create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, variable: 'shared') }

      it 'allows the same variable in both no-formula and variant scopes' do
        variant_link = described_class.new(variant: variant, sms_plan: sms_plan, session: sms_plan.session,
                                           url: 'https://x.com', link_type: 'website', variable: 'shared')
        expect(variant_link).to be_valid
      end
    end
  end

  include SchemaAssertionHelpers

  def raw_link(overrides = {})
    SmsLink.new({ url: 'https://example.test/canary-target', variable: 'canary_link', link_type: 'website',
                  campaign_id: campaign.id }.merge(overrides))
  end

  it 'stores a campaign link without a session and a plan' do
    link = raw_link.tap { |l| l.save!(validate: false) }.reload
    expect([link.session_id, link.sms_plan_id, link.campaign_id]).to eq([nil, nil, campaign.id])
  end

  it 'rejects the same variable twice inside one campaign at the database level' do
    raw_link.save!(validate: false)
    expect_unique_violation { raw_link(url: 'https://example.test/other').save!(validate: false) }
  end

  it 'allows the same variable in different campaigns at the database level' do
    other = create(:pdp_sms_campaign, intervention: campaign.intervention, kind: 'manual_reminder')
    raw_link.save!(validate: false)
    expect { raw_link(campaign_id: other.id).save!(validate: false) }.not_to raise_error
  end

  it 'keeps the legacy plan-bound unique indexes working' do
    existing = create(:sms_link, variable: 'canary_link')
    duplicate = described_class.new(sms_plan_id: existing.sms_plan_id, session_id: existing.session_id,
                                    url: existing.url, variable: 'canary_link', link_type: 'website')
    expect_unique_violation { duplicate.save!(validate: false) }
  end

  describe 'optional associations' do
    it 'treats sms_plan, session and campaign as optional' do
      link = described_class.new
      expect(link).to belong_to(:sms_plan).optional
      expect(link).to belong_to(:session).optional
      expect(link).to belong_to(:campaign).class_name('PredefinedParticipants::SmsCampaign').optional
    end

    it 'is valid as a campaign link without session and plan' do
      expect(build(:pdp_campaign_sms_link, campaign: campaign_a)).to be_valid
    end
  end

  describe 'uniqueness' do
    it 'accepts the same variable in two different campaigns' do
      create(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link')
      expect(build(:pdp_campaign_sms_link, campaign: campaign_b, variable: 'canary_link')).to be_valid
    end

    it 'accepts the same url and variable in two different campaigns' do
      create(:pdp_campaign_sms_link, campaign: campaign_a)
      expect { create(:pdp_campaign_sms_link, campaign: campaign_b) }.not_to raise_error
    end

    it 'rejects the same variable twice in one campaign' do
      create(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link')
      duplicate = build(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link',
                                                url: 'https://example.test/another-target')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:variable]).to be_present
    end

    it 'accepts different variables in one campaign' do
      create(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link')
      expect(build(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link_two',
                                           url: 'https://example.test/another-target')).to be_valid
    end

    it 'accepts two different-variable campaign links with the same url (no NULL plan collision)' do
      create(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link')
      expect(build(:pdp_campaign_sms_link, campaign: campaign_a, variable: 'canary_link_two')).to be_valid
    end

    it 'keeps the plan-scoped uniqueness for plan links' do
      existing = create(:sms_link, variable: 'canary_link')
      duplicate = build(:sms_link, sms_plan: existing.sms_plan, session: existing.session,
                                   variable: 'canary_link', url: 'https://example.test/another-target')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:variable]).to be_present
    end
  end

  describe 'URL scheme validation' do
    it 'rejects javascript://canary on a campaign link' do
      link = build(:pdp_campaign_sms_link, campaign: campaign_a, url: 'javascript://canary')
      expect(link).not_to be_valid
      expect(link.errors[:url]).to be_present
    end

    it 'rejects javascript://canary on a plan link as well' do
      link = build(:sms_link, url: 'javascript://canary')
      expect(link).not_to be_valid
      expect(link.errors[:url]).to be_present
    end

    it 'refuses to persist javascript://canary' do
      expect { create(:pdp_campaign_sms_link, campaign: campaign_a, url: 'javascript://canary') }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects other schemes such as ftp' do
      link = build(:pdp_campaign_sms_link, campaign: campaign_a, url: 'ftp://example.test/canary-target')
      expect(link).not_to be_valid
      expect(link.errors[:url]).to be_present
    end

    it 'accepts https' do
      expect(build(:pdp_campaign_sms_link, campaign: campaign_a, url: 'https://example.test/canary-target')).to be_valid
    end

    it 'accepts http' do
      expect(build(:pdp_campaign_sms_link, campaign: campaign_a, url: 'http://example.test/canary-target')).to be_valid
    end

    it 'accepts a bare host that gets https:// prepended' do
      link = build(:pdp_campaign_sms_link, campaign: campaign_a, url: 'example.test/canary-target')
      expect(link).to be_valid
      expect(link.url).to eq('https://example.test/canary-target')
    end
  end
end

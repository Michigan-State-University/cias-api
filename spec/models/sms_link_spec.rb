# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsLink, type: :model do
  describe 'associations' do
    it { should belong_to(:sms_plan) }
    it { should belong_to(:session) }
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
end

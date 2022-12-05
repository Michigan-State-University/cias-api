# frozen_string_literal: true

RSpec.describe Import::V1::SmsPlan::VariantService do
  subject { described_class.call(sms_plan_id, sms_plan_variant_hash) }

  let(:sms_plan) { create(:sms_plan) }
  let(:sms_plan_id) { sms_plan.id }
  let(:sms_plan_variant_hash) do
    {
      formula_match: 'yes',
      content: 'jak to jest byc skryba, dobrze?',
      original_text: { 'content' => 'how good is being a scribe?' },
      position: 1,
      version: '1'
    }
  end

  it 'creates sms variant' do
    expect { subject }.to change(SmsPlan::Variant, :count).by 1
  end

  it 'creates variant with correct attributes' do
    subject
    expect(
      SmsPlan::Variant.first.attributes.transform_keys(&:to_sym).except(:updated_at, :created_at, :sms_plan_id, :id)
    ).to include(sms_plan_variant_hash.except(:version))
  end
end

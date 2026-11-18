# frozen_string_literal: true

RSpec.describe Import::V1::SmsPlanService do
  subject { described_class.call(session_id, sms_plan_hash) }

  let(:sms_plan_hash) do
    {
      type: SmsPlan::Normal.name,
      name: 'Test',
      schedule: 'after_session_end',
      schedule_payload: nil,
      frequency: 'once',
      end_at: DateTime.now + 5.days,
      formula: '=0',
      no_formula_text: 'No formula',
      is_used_formula: false,
      original_text: { 'no_formula_text' => '' },
      include_first_name: false,
      include_last_name: false,
      include_phone_number: false,
      include_email: false,
      version: '1',
      variants: []
    }
  end

  let(:session) { create(:session) }
  let(:session_id) { session.id }

  it 'creates an sms plan' do
    expect { subject }.to change(SmsPlan, :count).by(1)
  end

  it 'creates sms plan with correct attributes' do
    subject
    expect(
      SmsPlan.first.attributes.transform_keys(&:to_sym).except(:created_at, :updated_at, :session_id, :variants, :id, :end_at)
    ).to include(sms_plan_hash.except(:variants, :version, :end_at))

    fmt = '%Y/%m/%d %H:%M:%S'
    # because it differs by like 100 milliseconds so we have to compare strings
    expect(sms_plan_hash[:end_at].in_time_zone('UTC').strftime(fmt)).to eq SmsPlan.first.end_at.in_time_zone('UTC').strftime(fmt)
  end

  context 'when sms_links are present in the hash (no-formula links)' do
    before do
      sms_plan_hash[:sms_links] = [
        { url: 'https://promo.example.com', link_type: 'website', variable: 'promo' }
      ]
    end

    it 'creates the sms_links' do
      expect { subject }.to change(SmsLink, :count).by(1)
    end

    it 'creates sms_links with correct attributes and no variant_id' do
      subject
      link = SmsLink.last
      expect(link).to have_attributes(
        url: 'https://promo.example.com',
        link_type: 'website',
        variable: 'promo',
        variant_id: nil
      )
      expect(link.sms_plan_id).to eq(SmsPlan.last.id)
    end
  end
end

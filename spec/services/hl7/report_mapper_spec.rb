# frozen_string_literal: true

require 'rails_helper'

describe Hl7::ReportMapper do
  subject(:segments) { described_class.call(report.id, user_session.id) }

  include_context 'with HL7 settings configured'

  let(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let(:user_session) { create(:user_session, user: patient) }
  let(:report) do
    create(:generated_report, :with_pdf_report, report_for: 'henry_ford_health', user_session: user_session)
  end
  let(:report_date) { report.created_at.in_time_zone(ENV.fetch('HFH_REPORT_TIMEZONE', nil)).strftime('%Y%m%d%H%M') }
  let(:pdf_base64) { Base64.strict_encode64(Rails.root.join('spec/fixtures/pdf/example_report.pdf').binread) }

  before { patient.hfhs_patient_detail.update!(visit_id: 'H1_1_1') }

  it 'builds the PV1, TXA and OBX segments with the configured TXA-2 and OBX-5 prefix' do
    expect(segments).to eq(
      [
        'PV1||O|||||||||||||||||H1_1_1',
        "TXA||DASST-D||#{report_date}||||||||89000344|||||AU||AV",
        "OBX|1|ED|||EpicWBS^PDF^Base64^#{pdf_base64}"
      ]
    )
  end

  %w[HL7_DOCUMENT_TYPE HL7_OBSERVATION_VALUE_PREFIX].each do |setting|
    context "when #{setting} is blank" do
      include_context 'with environment variables', { setting => '' }

      it 'raises an error naming the setting instead of building the segments' do
        expect { segments }.to raise_error(Ehr::Settings::MissingSettingError, "#{setting} is not set")
      end
    end
  end
end

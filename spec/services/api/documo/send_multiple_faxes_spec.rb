# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::Documo::SendMultipleFaxes do
  subject { described_class.call(fax_numbers, attachments, include_cover_page, fields, logo) }

  let!(:fax_numbers) { ['+1 202-222-2242', '+1 202-222-2243'] }
  let!(:generated_report) { create(:generated_report, :with_pdf_report) }
  let!(:attachments) { [generated_report.pdf_report] }
  let!(:include_cover_page) { true }
  let!(:logo) { create(:report_template, :with_logo).logo }
  let(:fields) { {} }

  it 'service return status and body received from the API' do
    stub_request(:post, "#{ENV.fetch('BASE_DOCUMO_URL')}/v1/faxes/multiple".to_s)
      .to_return(status: 200, body: File.read('spec/fixtures/integrations/documo/send_multiple_faxes.json'))
    expect(subject.keys).to match_array(%i[status body])
    expect(subject[:status]).to eq 200
    expect(subject[:body]).to match(File.open('spec/fixtures/integrations/documo/send_multiple_faxes.json') { |file| JSON.parse(file) })
  end

  context 'without logo' do
    subject { described_class.new(fax_numbers, attachments, include_cover_page, fields, logo) }

    let!(:logo) { nil }

    it '#custom_fields returns correct hash' do
      expect(subject.send(:custom_fields)).to include(logo: '')
    end
  end
end

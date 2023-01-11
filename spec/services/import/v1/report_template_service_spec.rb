# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::ReportTemplateService do
  subject { described_class.call(session_id, report_template_hash) }

  let(:report_template_hash) do
    {
      name: 'New Report 1',
      report_for: 'participant',
      summary: nil,
      original_text: {
        name: '',
        summary: ''
      },
      version: '1',
      sections: []
    }
  end

  let(:session_id) { create(:session).id }

  it 'create question group' do
    expect { subject }.to change(ReportTemplate, :count).by(1)
  end
end

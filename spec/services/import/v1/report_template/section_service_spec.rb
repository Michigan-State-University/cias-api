# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::ReportTemplate::SectionService do
  subject { described_class.call(report_template_id, section_hash) }

  let(:section_hash) do
    {
      formula: 'formula',
      position: 0,
      version: '1',
      variants: []
    }
  end

  let(:report_template_id) { create(:report_template).id }

  it 'create section' do
    expect { subject }.to change(ReportTemplate::Section, :count).by(1)
  end
end

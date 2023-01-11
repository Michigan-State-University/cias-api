# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::ReportTemplate::Section::VariantService do
  subject { described_class.call(report_template_section_id, variant_hash) }

  let(:variant_hash) do
    {
      preview: true,
      formula_match: '=1',
      title: '',
      content: 'test formula 1',
      original_text: {
        title: '',
        content: ''
      },
      version: '1'
    }
  end

  let(:report_template_section_id) { create(:report_template_section).id }

  it 'create variant' do
    expect { subject }.to change(ReportTemplate::Section::Variant, :count).by(1)
  end
end

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

  context 'with attached images' do
    let(:report_template_hash) do
      {
        name: 'New Report 1',
        report_for: 'participant',
        summary: nil,
        original_text: {
          name: '',
          summary: ''
        },
        logo: {
          extension: 'jpg',
          content_type: 'image/jpeg',
          description: nil,
          file: Base64.encode64('fake_image_data')
        },
        cover_letter_custom_logo: {
          extension: 'jpg',
          content_type: 'image/jpeg',
          description: nil,
          file: Base64.encode64('fake_image_data')
        },
        version: '1',
        sections: []
      }
    end

    it 'template has attached logo' do
      result = subject

      expect(result.logo.attached?).to be true
      expect(ActiveStorage::Blob.service.exist?(result.logo.blob.key)).to be true
    end

    it 'template has attached cover_letter_custom_logo' do
      result = subject

      expect(result.cover_letter_custom_logo.attached?).to be true
      expect(ActiveStorage::Blob.service.exist?(result.cover_letter_custom_logo.blob.key)).to be true
    end
  end
end

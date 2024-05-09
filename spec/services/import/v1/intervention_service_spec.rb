# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::InterventionService do
  subject { described_class.call(user_id, intervention_hash) }

  let(:intervention_hash) do
    {
      name: 'New e-Intervention',
      quick_exit: false,
      type: 'Intervention',
      additional_text: '',
      original_text: {
        additional_text: ''
      },
      language_name: 'English',
      language_code: 'en',
      logo: {
        extension: 'png',
        content_type: logo.content_type,
        description: 'Alt',
        file: Base64.encode64(logo_data)
      },
      version: '1',
      sessions: [],
      intervention_accesses: []
    }
  end
  let(:user_id) { create(:user, :researcher).id }
  let(:logo) { FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true) }

  let(:logo_data) do
    File.binread(logo.path)
  end

  it 'create intervention' do
    expect { subject }.to change(Intervention, :count).by(1)
  end

  it 'send email' do
    expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end

  it 'create notification' do
    expect { subject }.to change(Notification, :count).by(1)
  end

  it 'have correct google language' do
    expect(subject.google_language.attributes.except('id', 'created_at', 'updated_at',
                                                     'google_tts_language_id').deep_transform_keys(&:to_sym)).to match({ language_name: 'English',
                                                                                                                         language_code: 'en' })
  end

  it 'have correct intervention logo file' do
    expect(subject.logo.blob.download).to eq(logo_data)
  end

  it 'have correct intervention logo content type' do
    expect(subject.logo.blob.content_type).to eq(logo.content_type)
  end

  it 'have correct logo description' do
    expect(subject.logo_blob.description).to eq(intervention_hash[:logo][:description])
  end
end

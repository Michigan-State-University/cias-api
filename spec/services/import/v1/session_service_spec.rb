# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::SessionService do
  subject { described_class.call(intervention_id, session_hash) }

  let(:session_hash) do
    {
      settings: {
        narrator: {
          voice: true,
          animation: true
        }
      },
      position: 1,
      name: 'New Session',
      schedule: 'after_fill',
      schedule_payload: nil,
      schedule_at: nil,
      formulas: [
        {
          payload: '',
          patterns: []
        }
      ],
      variable: 's5562',
      days_after_date_variable_name: nil,
      type: 'Session::Classic',
      original_text: {
        name: ''
      },
      estimated_time: nil,
      body: {
        data: []
      },
      voice_type: 'en-US-Standard-C',
      voice_label: 'Standard-female-1',
      language_code: 'en-US',
      version: '1',
      sms_plans: [],
      question_groups: [],
      report_templates: []
    }
  end

  let(:intervention_id) { create(:intervention).id }

  it 'create session' do
    expect { subject }.to change(Session, :count).by(1)
  end

  it 'have correct google tts voice' do
    expect(subject.google_tts_voice.attributes.except('id', 'created_at', 'updated_at',
                                                      'google_tts_language_id').deep_transform_keys(&:to_sym)).to match({ voice_label: 'Standard-female-1',
                                                                                                                          language_code: 'en-US',
                                                                                                                          voice_type: 'en-US-Standard-C' })
  end

  it 'has no question groups' do
    expect { subject }.not_to change(QuestionGroup, :count)
  end
end

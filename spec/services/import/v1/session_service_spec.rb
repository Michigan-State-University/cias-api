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

  describe 'remapping report_template_ids on Question::ThirdParty bodies' do
    let(:source_template_id_one) { SecureRandom.uuid }
    let(:source_template_id_two) { SecureRandom.uuid }
    let(:orphan_source_template_id) { SecureRandom.uuid }

    let(:third_party_question_hash) do
      {
        type: 'Question::ThirdParty',
        settings: { required: false },
        position: 1,
        title: 'Third party',
        subtitle: '',
        narrator: { blocks: [], settings: { voice: true, animation: true, character: 'peedy' } },
        video_url: nil,
        formulas: [],
        body: {
          data: [
            { payload: '', value: 'a@example.com', report_template_ids: [source_template_id_one] },
            { payload: '', value: 'b@example.com', report_template_ids: [source_template_id_two, orphan_source_template_id] }
          ],
          variable: { name: '' }
        },
        original_text: { title: '', subtitle: '', image_description: '' },
        duplicated: true,
        image: nil,
        version: '1'
      }
    end

    let(:report_templates_hash) do
      [
        {
          id: source_template_id_one,
          name: 'Template Alpha',
          report_for: 'third_party',
          summary: nil,
          original_text: { name: '', summary: '' },
          version: '1',
          sections: []
        },
        {
          id: source_template_id_two,
          name: 'Template Beta',
          report_for: 'third_party',
          summary: nil,
          original_text: { name: '', summary: '' },
          version: '1',
          sections: []
        }
      ]
    end

    let(:session_hash) do
      super().merge(
        question_groups: [
          {
            title: 'Group 1',
            position: 1,
            type: 'QuestionGroup::Plain',
            version: '1',
            questions: [third_party_question_hash]
          }
        ],
        report_templates: report_templates_hash
      )
    end

    it 'rewrites report_template_ids to the newly created template UUIDs' do
      session = subject
      question = Question::ThirdParty.joins(:question_group).find_by(question_groups: { session_id: session.id })
      template_alpha = ReportTemplate.find_by!(session_id: session.id, name: 'Template Alpha')
      template_beta = ReportTemplate.find_by!(session_id: session.id, name: 'Template Beta')

      expect(question.body_data[0]['report_template_ids']).to eq([template_alpha.id])
      expect(question.body_data[1]['report_template_ids']).to contain_exactly(template_beta.id)
    end

    it 'drops orphan source IDs not present in the imported report_templates array' do
      session = subject
      question = Question::ThirdParty.joins(:question_group).find_by(question_groups: { session_id: session.id })

      flattened = question.body_data.flat_map { |row| row['report_template_ids'] }
      expect(flattened).not_to include(orphan_source_template_id)
    end

    it 'creates new ReportTemplate rows with fresh UUIDs (does not adopt the source id)' do
      session = subject
      created_ids = ReportTemplate.where(session_id: session.id).pluck(:id)

      expect(created_ids).not_to include(source_template_id_one, source_template_id_two)
    end

    context 'with a legacy export (report_templates hashes carry no :id)' do
      let(:report_templates_hash) do
        [
          {
            name: 'Template Alpha',
            report_for: 'third_party',
            summary: nil,
            original_text: { name: '', summary: '' },
            version: '1',
            sections: []
          }
        ]
      end

      it 'imports without raising and leaves the question body untouched' do
        session = subject
        question = Question::ThirdParty.joins(:question_group).find_by(question_groups: { session_id: session.id })

        expect(question.body_data[0]['report_template_ids']).to eq([source_template_id_one])
      end
    end

    context 'with a non-third-party question and a participant report template' do
      let(:single_question_hash) do
        {
          type: 'Question::Single',
          settings: { image: false, title: true, video: false, required: true, subtitle: true, proceed_button: true, narrator_skippable: false },
          position: 2,
          title: 'Pick one',
          subtitle: '',
          narrator: { blocks: [], settings: { voice: true, animation: true, character: 'peedy' } },
          video_url: nil,
          formulas: [],
          body: { data: [{ value: '1', payload: '' }], variable: { name: '' } },
          original_text: { title: '', subtitle: '', image_description: '' },
          duplicated: true,
          image: nil,
          version: '1'
        }
      end

      let(:session_hash) do
        super().merge(
          question_groups: [
            {
              title: 'Group 1',
              position: 1,
              type: 'QuestionGroup::Plain',
              version: '1',
              questions: [single_question_hash]
            }
          ],
          report_templates: [
            {
              id: SecureRandom.uuid,
              name: 'Participant Template',
              report_for: 'participant',
              summary: nil,
              original_text: { name: '', summary: '' },
              version: '1',
              sections: []
            }
          ]
        )
      end

      it 'leaves the non-third-party question body untouched' do
        session = subject
        question = Question::Single.joins(:question_group).find_by(question_groups: { session_id: session.id })

        expect(question.body_data).to eq([{ 'value' => '1', 'payload' => '' }])
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportTemplate, type: :model do
  it { should belong_to(:session) }
  it { should have_many(:generated_reports) }

  describe '#name' do
    context 'name is unique for a session' do
      let!(:existing_report_template) { create(:report_template) }
      let(:report_template) { build_stubbed(:team, name: existing_report_template.name) }

      it 'team is valid' do
        expect(report_template).to be_valid
      end
    end

    context 'name is not unique in session' do
      let!(:existing_report_template) { create(:report_template) }
      let(:report_template) do
        build_stubbed(
          :report_template,
          name: existing_report_template.name,
          session: existing_report_template.session
        )
      end

      it 'report template is invalid' do
        expect(report_template).not_to be_valid
        expect(report_template.errors.messages[:name]).to include(/has already been taken/)
      end
    end

    context 'name is blank' do
      let(:report_template) { build_stubbed(:team, name: '') }

      it 'report template is invalid' do
        expect(report_template).not_to be_valid
        expect(report_template.errors.messages[:name]).to include(/can't be blank/)
      end
    end

    context 'name is present' do
      let(:report_template) { build_stubbed(:team) }

      it 'report template is valid' do
        expect(report_template).to be_valid
      end
    end
  end

  describe 'translation' do
    let(:translator) { V1::Google::TranslationService.new }
    let(:source_language_short) { 'en' }
    let(:destination_language_short) { 'pl' }

    let(:translation_test_report_template) do
      create(:report_template, summary: 'Translation test summary', name: 'Test report template name')
    end

    it '#translate_summary' do
      translation_test_report_template.translate_summary(translator, source_language_short, destination_language_short)
      expect(translation_test_report_template.summary).to include('from=>en to=>pl text=>Translation test summary')
    end

    it '#translate_name' do
      translation_test_report_template.translate_name(translator, source_language_short, destination_language_short)
      expect(translation_test_report_template.name).to include('from=>en to=>pl text=>Test report template name')
    end
  end

  describe 'clone' do
    subject { report_template.clone }

    let!(:report_template) { create(:report_template, :with_logo, :with_sections, :with_cover_letter_custom_logo) }

    it 'create a copy in the exising session' do
      expect(subject.name).to eq("Copy of #{report_template.name}")
    end

    it 'belongs to correct session' do
      expect(subject.session_id).to eq(report_template.session_id)
    end

    it 'has attached logo' do
      expect(subject.logo.attached?).to be true
    end

    it 'has attached cover letter custom log' do
      expect(subject.cover_letter_custom_logo.attached?).to be true
    end

    it 'has sections' do
      expect(subject.sections.any?).to be true
    end

    it 'create successfully new record' do
      expect { subject }.to change(described_class, :count).by(1)
    end

    it 'has "is_duplicated_from_other_session" flag off' do
      expect(subject.is_duplicated_from_other_session).to eq(false)
    end

    context 'when we duplicate template to other session' do
      subject { Clone::ReportTemplate.new(report_template, params: { session_id: session.id }).execute }

      let(:session) { create(:session) }

      it 'create a template' do
        expect { subject }.to change(described_class, :count).by(1)
      end

      it 'new template belongs to the specified session' do
        expect(subject.session.id).to eq(session.id)
      end

      it 'has "is_duplicated_from_other_session" flag on' do
        expect(subject.reload.is_duplicated_from_other_session).to eq(true)
      end

      context 'when the option to set flag is off' do
        subject { Clone::ReportTemplate.new(report_template, params: { session_id: session.id }, set_flag: false).execute }

        it 'has "is_duplicated_from_other_session" flag on' do
          expect(subject.is_duplicated_from_other_session).to eq(false)
        end
      end
    end

    context 'collision with names' do
      let!(:report_template1) { create(:report_template, session: report_template.session, name: "2nd copy of #{report_template.name}") }

      it 'create a copy in the exising session' do
        expect(subject.name).to eq("Copy of #{report_template.name}")
      end

      context 'should get next in order prefix' do
        let!(:report_template2) { create(:report_template, session: report_template.session, name: "Copy of #{report_template.name}") }
        let!(:report_template3) { create(:report_template, session: report_template.session, name: "4th copy of #{report_template.name}") }

        it 'create a copy in the exising session' do
          expect(subject.name).to eq("5th copy of #{report_template.name}")
        end
      end
    end
  end
end

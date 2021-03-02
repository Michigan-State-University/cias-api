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
end

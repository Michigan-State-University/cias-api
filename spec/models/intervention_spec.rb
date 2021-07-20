# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  context 'Intervention' do
    subject { create(:intervention) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should have_many(:sessions) }
    it { should belong_to(:google_language) }
    it { should be_valid }
    it { expect(initial_status.draft?).to be true }
  end

  describe 'instance methods' do
    describe 'translation' do
      let(:intervention) { create(:intervention_with_logo, name: 'New intervention') }
      let(:translator) { V1::Google::TranslationService.new }
      let(:source_language_name_short) { 'en' }
      let(:destination_language_name_short) { 'pl' }

      before do
        intervention.logo_blob.description = 'This is the description'
        intervention.translate(translator, source_language_name_short, destination_language_name_short)
      end

      describe '#translation_prefix' do
        it 'add correct prefix' do
          expect(intervention.reload.name).to include("(#{destination_language_name_short.upcase}) New intervention")
        end
      end
    end
  end
end

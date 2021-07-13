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

  context 'change states' do
    context 'from draft' do
      let(:intervention) { create(:intervention) }
      let!(:sessions) { create_list(:session, 4, intervention_id: intervention.id) }

      context 'to published' do
        it 'success event' do
          intervention.broadcast
          expect(intervention.published?).to be true
        end
      end

      context 'to closed' do
        it 'no status change' do
          intervention.close
          expect(intervention.draft?).to be true
        end
      end

      context 'to archived' do
        it 'success event' do
          intervention.to_archive
          expect(intervention.archived?).to be true
        end
      end
    end

    context 'from published' do
      let(:intervention) { create(:intervention, :published) }

      context 'to closed' do
        it 'success event' do
          intervention.close
          expect(intervention.closed?).to be true
        end
      end

      context 'to archived' do
        it 'no status change' do
          intervention.to_archive
          expect(intervention.published?).to be true
        end
      end
    end

    context 'from closed' do
      let(:intervention) { create(:intervention, :closed) }

      context 'to published' do
        it 'no status change' do
          intervention.broadcast
          expect(intervention.closed?).to be true
        end
      end

      context 'to archived' do
        it 'success event' do
          intervention.to_archive
          expect(intervention.archived?).to be true
        end
      end
    end

    context 'from archived' do
      let(:intervention) { create(:intervention, :archived) }

      context 'to published' do
        it 'no status change' do
          intervention.broadcast
          expect(intervention.archived?).to be true
        end
      end

      context 'to closed' do
        it 'no status change' do
          intervention.close
          expect(intervention.archived?).to be true
        end
      end
    end
  end

  describe 'instance methods' do
    describe 'translation' do
      let(:intervention) { create(:intervention_with_logo) }
      let(:translator) { V1::Google::TranslationService.new }
      let(:source_language_name_short) { 'en' }
      let(:destination_language_name_short) { 'pl' }

      before do
        intervention.translate(translator, source_language_name_short, destination_language_name_short)
      end

      describe '#translation_prefix' do
        it 'add correct prefix' do
          expect(intervention.reload.name).to include("(#{destination_language_name_short.upcase})")
        end
      end

      describe '#translate_logo_description' do
        it 'add original text' do
          expect(intervention.original_text['logo_description']).to equal(nil)
        end

        it 'have correct description' do
          expect(intervention.logo_blob.description).to equal(nil)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Question, type: :model do
  describe 'callbacks' do
    context 'after_create' do
      context 'when question has type Question::Finish' do
        let(:question_finish) { create(:question_finish) }

        it 'creates default block' do
          expect(question_finish['narrator']['blocks'].size).to eq(1)
        end
      end

      context 'when question has different type' do
        let(:question_single) { create(:question_single) }

        it 'does not create default block' do
          expect(question_single['narrator']['blocks'].size).to eq(0)
        end
      end
    end
  end

  context 'clone' do
    let(:question) { create(:question_single) }

    it 'copied image should be independent from the original image' do
      question.image_blob.update(description: 'example description')
      cloned_question = question.clone
      expect(cloned_question.image_blob.description).to eq(question.image_blob.description)

      question.image_blob.update(description: 'new description')
      expect(cloned_question.image_blob.description).not_to eq(question.image_blob.description)
    end
  end

  describe 'instance methods' do
    let(:question) { create(:question_single) }

    it 'returns correct variable with clone index' do
      expect(question.variable_with_clone_index(%w[test test2 clone_test], 'test')).to eq('clone1_test')
      expect(question.variable_with_clone_index(%w[clone1_test clone3_test clone_test], 'test')).to eq('clone2_test')
      expect(question.variable_with_clone_index(%w[clone1_test clone_test clone2_test], 'test')).to eq('clone3_test')
    end
  end

  describe '#type_supported_for_ra_session' do
    let(:ra_session) { create(:ra_session) }
    let(:ra_question_group) { create(:question_group, session: ra_session) }
    let(:classic_session) { create(:session) }
    let(:classic_question_group) { create(:question_group, session: classic_session) }

    Session::ResearchAssistant::SUPPORTED_QUESTION_TYPES.each do |supported_type|
      factory_name = :"question_#{supported_type.demodulize.underscore}"

      it "allows #{supported_type} in an RA session" do
        question = build(factory_name, question_group: ra_question_group)
        expect(question).to be_valid
      end
    end

    it 'allows Question::Finish in an RA session (auto-included completion screen)' do
      question = build(:question_finish, question_group: ra_question_group)
      expect(question).to be_valid
    end

    it 'rejects Question::Multiple in an RA session with code :unsupported_in_ra_session' do
      question = build(:question_multiple, question_group: ra_question_group)
      expect(question).not_to be_valid
      expect(question.errors.details[:type]).to include(error: :unsupported_in_ra_session)
    end

    it 'rejects Question::FreeResponse in an RA session with code :unsupported_in_ra_session' do
      question = build(:question_free_response, question_group: ra_question_group)
      expect(question).not_to be_valid
      expect(question.errors.details[:type]).to include(error: :unsupported_in_ra_session)
    end

    it 'allows any non-supported type in a non-RA session (no cross-class restriction)' do
      question = build(:question_multiple, question_group: classic_question_group)
      expect(question).to be_valid
    end

    it 'short-circuits when question_group is nil (does not crash on validation)' do
      question = build(:question_multiple, question_group: nil)
      # Other validations may flag question_group presence; we only assert this validation
      # does not add a :unsupported_in_ra_session error and does not raise.
      expect { question.valid? }.not_to raise_error
      expect(question.errors.details[:type]).not_to include(error: :unsupported_in_ra_session)
    end
  end
end

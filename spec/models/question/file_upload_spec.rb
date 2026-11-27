# frozen_string_literal: true

RSpec.describe Question::FileUpload, type: :model do
  describe 'expected behaviour' do
    subject(:question_file_upload) { build(:question_file_upload) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'validation of question assignments' do
    let(:question) { build(:question_file_upload, question_group: question_group) }

    it_behaves_like 'cannot be assigned to sms session'
    it_behaves_like 'can be assigned to classic session'
  end

  describe 'default settings' do
    subject(:question_file_upload) { create(:question_file_upload) }

    it 'is required by default' do
      expect(question_file_upload.settings['required']).to be(true)
    end

    it 'hides the file description field by default' do
      expect(question_file_upload.settings['show_file_description']).to be(false)
    end
  end

  describe '#question_variables' do
    subject(:question_file_upload) { create(:question_file_upload) }

    it 'returns exactly one variable' do
      expect(question_file_upload.question_variables).to contain_exactly('file_upload_var')
    end
  end

  describe '#extract_variables_from_params' do
    subject(:question_file_upload) { build(:question_file_upload) }

    it 'returns the variable name from params' do
      params = { body: { variable: { name: 'new_var' } } }
      expect(question_file_upload.extract_variables_from_params(params)).to eq([{ 'name' => 'new_var' }])
    end

    it 'returns an empty array when the name is blank' do
      params = { body: { variable: { name: '' } } }
      expect(question_file_upload.extract_variables_from_params(params)).to eq([])
    end
  end

  describe 'body schema' do
    it 'rejects an empty body' do
      expect(build(:question_file_upload, :body_data_empty).save).to be(false)
    end
  end
end

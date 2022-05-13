# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportTemplate::Section::Variant, type: :model do
  it { should belong_to(:report_template_section) }
  it { should validate_content_type_of(:image).allowing('image/png', 'image/jpg', 'image/jpeg') }
  it { should validate_content_type_of(:image).rejecting('text/plain', 'application/pdf') }
  it { should validate_size_of(:image).less_than_or_equal_to(5.megabytes) }

  describe 'translation' do
    let(:translator) { V1::Google::TranslationService.new }
    let(:variants) { create_list(:report_template_section_variant, 5) }
    let(:source_language_short) { 'en' }
    let(:destination_language_short) { 'pl' }
    let(:results) { [] }

    it '#translate_title' do
      variants.each do |variant|
        variant.translate_title(translator, source_language_short, destination_language_short)
        results << variant.title.include?(
          "from=>#{source_language_short} to=>#{destination_language_short} text=>#{variant.original_text['title']}".to_s
        )
      end
      expect(results).to all(be_truthy)
    end

    it '#translate_content' do
      variants.each do |variant|
        variant.translate_content(translator, source_language_short, destination_language_short)
        results << variant.content.include?(
          "from=>#{source_language_short} to=>#{destination_language_short} text=>#{variant.original_text['content']}"
        )
      end
      expect(results).to all(be_truthy)
    end
  end
end

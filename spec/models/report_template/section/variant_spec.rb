# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportTemplate::Section::Variant, type: :model do
  it { should belong_to(:report_template_section) }
  it { should validate_content_type_of(:image).allowing('image/png', 'image/jpg', 'image/jpeg') }
  it { should validate_content_type_of(:image).rejecting('text/plain', 'application/pdf') }
  it { should validate_size_of(:image).less_than_or_equal_to(5.megabytes) }
end

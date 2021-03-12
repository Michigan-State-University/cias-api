# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneratedReport, type: :model do
  it { should belong_to(:user_session) }
  it { should belong_to(:report_template) }
  it { should validate_content_type_of(:pdf_report).allowing('application/pdf') }
end

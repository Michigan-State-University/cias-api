# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PredefinedUserParameter, type: :model do
  subject { create(:predefined_user_parameter) }

  it { should belong_to(:user) }
  it { should belong_to(:intervention) }
  it { should belong_to(:health_clinic).optional(true) }
  it { should validate_uniqueness_of(:slug) }

  it '#generate_slug' do
    expect(described_class.create!(user: create(:user), intervention: create(:intervention)).slug).to be_present
  end
end

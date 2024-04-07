# frozen_string_literal: true

RSpec.describe Session::Sms, type: :model do
  it { should have_many(:question_groups) }
  it { should have_many(:questions) }
end

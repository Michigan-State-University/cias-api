# frozen_string_literal: true

RSpec.describe Session::Classic, type: :model do
  it { should have_many(:question_groups) }
  it { should have_many(:questions) }
end

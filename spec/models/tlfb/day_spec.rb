# frozen_string_literal: true

RSpec.describe Tlfb::Day, type: :model do
  it { should belong_to(:question_group) }
  it { should belong_to(:user_session) }
end

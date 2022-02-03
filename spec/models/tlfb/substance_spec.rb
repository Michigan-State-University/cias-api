# frozen_string_literal: true

RSpec.describe Tlfb::Substance, type: :model do
  it { should belong_to(:user_session) }
end

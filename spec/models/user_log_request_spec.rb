# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserLogRequest, type: :model do
  subject { create(:user_log_request) }

  it { should belong_to(:user) }
  it { should be_valid }
end

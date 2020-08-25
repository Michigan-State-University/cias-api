# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Address, type: :model do
  describe 'Address' do
    subject { create(:address) }

    it { should be_valid }
    it { should belong_to(:user) }
  end
end

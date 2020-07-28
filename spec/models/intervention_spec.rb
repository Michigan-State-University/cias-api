# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  describe 'Intervention' do
    subject { create(:intervention) }

    it { should belong_to(:user) }
    it { should have_many(:questions) }
    it { should be_valid }
  end
end

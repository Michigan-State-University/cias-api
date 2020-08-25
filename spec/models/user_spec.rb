# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  describe 'user' do
    subject { create(:user) }

    it { should be_valid }
    it { should have_many(:problems) }
    it { should have_one(:address) }
    it { should accept_nested_attributes_for(:address) }
  end

  describe 'admin' do
    subject { create(:user, :confirmed, :admin) }

    it { should be_valid }
    it { should have_many(:problems) }
    it { should have_one(:address) }
    it { should accept_nested_attributes_for(:address) }
  end
end

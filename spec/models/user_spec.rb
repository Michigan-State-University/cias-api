# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  describe 'participant' do
    subject { create(:user, :confirmed, :participant) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end

  describe 'admin' do
    subject { create(:user, :confirmed, :admin) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end
end

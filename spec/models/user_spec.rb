# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  subject(:user) { build(:user) }

  it { should be_valid }
  it { should have_many(:interventions) }
end

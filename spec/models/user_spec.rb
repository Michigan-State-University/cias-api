# frozen_string_literal: true

require 'rails_helper'

describe User do
  subject(:user) { build(:user) }

  it { should be_valid }
  it { should have_many(:interventions) }
end

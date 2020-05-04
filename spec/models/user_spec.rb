# frozen_string_literal: true

require 'rails_helper'

describe User do
  subject(:user) { build(:user) }

  it { is_expected.to be_valid }
end

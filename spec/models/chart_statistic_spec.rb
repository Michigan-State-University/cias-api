# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChartStatistic, type: :model do
  it { should belong_to(:organization) }
  it { should belong_to(:health_system) }
  it { should belong_to(:health_clinic) }
  it { should belong_to(:user) }
end

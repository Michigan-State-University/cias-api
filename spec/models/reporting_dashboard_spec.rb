# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportingDashboard, type: :model do
  it { should belong_to(:organization) }
end

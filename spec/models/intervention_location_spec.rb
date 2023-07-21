# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InterventionLocation, type: :model do
  subject { create(:intervention_location) }

  it { should belong_to(:intervention) }
  it { should belong_to(:clinic_location) }
end

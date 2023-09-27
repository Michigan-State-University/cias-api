# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClinicLocation, type: :model do
  subject { create(:clinic_location) }

  it { should have_many(:intervention_locations).dependent(:destroy) }
  it { should have_many(:interventions) }

  it { validate_presence_of(:department) }
  it { validate_presence_of(:name) }
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe(HfhsPatientDetail) do
  it { validate_presence_of(:patient_id) }
  it { validate_presence_of(:first_name) }
  it { validate_presence_of(:last_name) }
  it { validate_presence_of(:sex) }
  it { validate_presence_of(:zip_code) }
  it { validate_presence_of(:dob) }
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe(HfhsPatientDetail) do
  it { should validate_presence_of(:patient_id) }
end

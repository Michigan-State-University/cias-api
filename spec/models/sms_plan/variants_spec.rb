# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsPlan::Variant, type: :model do
  it { should belong_to(:sms_plan) }
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShortLink, type: :model do
  it { should(belong_to(:linkable)) }
  it { should(belong_to(:health_clinic).optional(true)) }
end

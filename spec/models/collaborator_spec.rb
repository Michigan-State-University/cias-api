# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Collaborator, type: :model do
  it { should belong_to(:intervention) }
  it { should belong_to(:user) }
end

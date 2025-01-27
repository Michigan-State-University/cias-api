# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Collaborator, type: :model do
  subject { create(:collaborator) }

  it { should belong_to(:intervention) }
  it { should belong_to(:user) }
  it { should validate_uniqueness_of(:user_id).scoped_to(:intervention_id).case_insensitive.with_message('is already a collaborator in this intervention') }
end

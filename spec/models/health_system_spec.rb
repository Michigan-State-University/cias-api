# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthSystem, type: :model do
  it { should belong_to(:organization) }
  it { should have_many(:health_clinics).dependent(:destroy) }

  describe '#name' do
    context 'name is unique' do
      let!(:existing_health_system) { create(:health_system) }
      let(:health_system) { build(:health_system) }

      it 'organization is valid' do
        expect(health_system).to be_valid
      end
    end

    context 'name is not unique' do
      let!(:existing_health_system) { create(:health_system) }
      let(:health_system) { build_stubbed(:health_system, name: existing_health_system.name, organization: existing_health_system.organization) }

      it 'team is invalid' do
        expect(health_system).not_to be_valid
        expect(health_system.errors.messages[:name]).to include(/has already been taken/)
      end
    end
  end
end

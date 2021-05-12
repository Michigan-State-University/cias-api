# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthClinic, type: :model do
  it { should belong_to(:health_system) }
  it { should have_many(:user_sessions) }
  it { should have_many(:invitations) }

  describe '#name' do
    context 'name is unique' do
      let!(:existing_health_clinic) { create(:health_clinic) }
      let(:health_clinic) { build(:health_clinic) }

      it 'health_clinic is valid' do
        expect(health_clinic).to be_valid
      end
    end

    context 'name is not unique' do
      let!(:existing_health_clinic) { create(:health_clinic) }
      let(:health_clinic) { build_stubbed(:health_clinic, name: existing_health_clinic.name, health_system: existing_health_clinic.health_system) }

      it 'health clinic is invalid' do
        expect(health_clinic).not_to be_valid
        expect(health_clinic.errors.messages[:name]).to include(/has already been taken/)
      end
    end
  end
end

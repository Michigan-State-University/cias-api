# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthSystem, type: :model do
  it { should belong_to(:organization) }
  it { should have_many(:health_clinics).dependent(:destroy) }
  it { should have_many(:health_system_admins) }
  it { should have_many(:health_system_invitations).dependent(:destroy) }
  it { should have_many(:chart_statistics) }

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
      let(:health_system) do
        HealthSystem.new(name: existing_health_system.name, organization: existing_health_system.organization)
      end

      it 'health system is invalid' do
        expect(health_system).not_to be_valid
        expect(health_system.errors.messages[:name]).to include(/has already been taken/)
      end
    end
  end

  describe '#health_clinics' do
    context 'when health_system has one deleted clinic and one not' do
      let!(:health_system) { create(:health_system) }
      let!(:deleted_health_clinic) { create(:health_clinic, health_system: health_system, deleted_at: Time.current) }
      let!(:health_clinic) { create(:health_clinic, health_system: health_system) }
      let(:health_clinic_ids) { [health_clinic.id, deleted_health_clinic.id] }

      it 'returns one health clinic with deleted one' do
        expect(health_system.health_clinics.size).to eq 2
      end

      it 'returns proper records' do
        expect(health_system.health_clinics.with_deleted.pluck(:id)).to eql(health_clinic_ids)
      end
    end
  end
end

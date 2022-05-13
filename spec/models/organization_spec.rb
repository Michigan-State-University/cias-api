# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  it { should have_many(:e_intervention_admins) }
  it { should have_many(:organization_admins) }
  it { should have_many(:health_systems).dependent(:destroy) }
  it { should have_many(:organization_invitations).dependent(:destroy) }
  it { should have_one(:reporting_dashboard).dependent(:destroy) }
  it { should have_many(:chart_statistics) }

  describe '#name' do
    context 'name is unique' do
      let(:organization) { build(:organization, :with_organization_admin) }

      it 'organization is valid' do
        expect(organization).to be_valid
      end
    end

    context 'name is not unique' do
      let!(:existing_organization) { create(:organization) }
      let(:organization) { build_stubbed(:organization, name: existing_organization.name) }

      it 'team is invalid' do
        expect(organization).not_to be_valid
        expect(organization.errors.messages[:name]).to include(/has already been taken/)
      end
    end
  end

  describe '#destroy' do
    context 'destroy all health systems' do
      let!(:organization) { create(:organization, :with_health_system) }

      it 'destroy all children' do
        expect { organization.destroy }.to change(described_class, :count).by(-1).and change(HealthSystem.with_deleted, :count).by(-1)
      end
    end
  end
end

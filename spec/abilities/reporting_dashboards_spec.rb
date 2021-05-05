# frozen_string_literal: true

require 'cancan/matchers'

describe ReportingDashboard do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'organization admin' do
      let!(:organization1) { create(:organization, :with_organization_admin) }
      let!(:dashboard1) { create(:reporting_dashboard, organization: organization1) }
      let!(:other_organization) { create(:organization) }
      let!(:other_dashboard) { create(:reporting_dashboard, organization: other_organization) }
      let(:user) { organization1.organization_admins.first }

      it 'can read reporting dashboards of organizations that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true
          },
          dashboard1
        )
      end

      it 'can\'t read other reporting dashboards' do
        expect(subject).to not_have_abilities(
          %i[read],
          other_dashboard
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'health system admin' do
      let!(:organization) { create(:organization) }
      let!(:health_system1) { create(:health_system, :with_health_system_admin, organization: organization) }
      let!(:dashboard1) { health_system1.organization.reporting_dashboard }

      let!(:other_health_system) { create(:health_system, organization: organization) }
      let!(:other_dashboard) { other_health_system.organization.reporting_dashboard }
      let(:user) { health_system1.health_system_admins.first }

      it 'can read reporting dashboards of organizations that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true
          },
          dashboard1
        )
      end

      it 'can\'t read other reporting dashboards' do
        expect(subject).to not_have_abilities(
          %i[read],
          other_dashboard
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'health clinic admin' do
      let!(:organization) { create(:organization) }
      let!(:health_system) { create(:health_system, organization: organization) }
      let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }
      let!(:dashboard) { health_clinic.health_system.organization.reporting_dashboard }

      let!(:other_health_clinic) { create(:health_clinic, health_system: health_system) }
      let!(:other_dashboard) { other_health_clinic.health_system.organization.reporting_dashboard }

      let(:user) { health_clinic.health_clinic_admins.first }

      it 'can read reporting dashboards of organizations that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true
          },
          dashboard
        )
      end

      it 'can\'t read other reporting dashboards' do
        expect(subject).to not_have_abilities(
          %i[read],
          other_dashboard
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'user can\'t read reporting dashboards of any organization' do
      %i[team_admin researcher participant guest].each do |role|
        context "current user is #{role}" do
          let(:user) { build_stubbed(:user, :confirmed, role) }

          it do
            expect(subject).to not_have_abilities(
              %i[read create update destroy],
              described_class
            )
          end
        end
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }
      let!(:organization1) { create(:organization) }
      let!(:organization2) { create(:organization) }

      it 'return all reporting dashboards' do
        expect(subject).to include(organization1.reporting_dashboard, organization2.reporting_dashboard)
      end
    end

    context 'organization_admin' do
      let!(:organization1) { create(:organization, :with_organization_admin) }
      let!(:other_organization) { create(:organization) }
      let(:user) { organization1.organization_admins.first }

      it 'return all organization_admin\'s organizations' do
        expect(subject).to include(organization1.reporting_dashboard).and not_include(other_organization.reporting_dashboard)
      end
    end
  end
end

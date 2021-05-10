# frozen_string_literal: true

require 'cancan/matchers'

describe Chart do
  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:other_organization) { create(:organization) }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:other_dashboard_section) { create(:dashboard_section, reporting_dashboard: other_organization.reporting_dashboard) }
  let!(:chart) { create(:chart, dashboard_section_id: dashboard_section.id) }
  let!(:other_chart) { create(:chart, dashboard_section_id: other_dashboard_section.id) }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'e-intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it 'can manage chart for organization that he is admin for' do
        expect(subject).to have_abilities(:manage, chart)
      end

      it 'can\'t read chard from other organization' do
        expect(subject).to not_have_abilities(:manage, other_organization)
      end
    end

    context 'user can\'t' do
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

      it 'return all charts' do
        expect(subject).to include(chart, other_chart)
      end
    end

    context 'organization_admin' do
      let(:user) { organization.e_intervention_admins.first }

      it 'return all organization_admin\'s organizations' do
        expect(subject).to include(chart).and not_include(other_chart)
      end
    end
  end
end

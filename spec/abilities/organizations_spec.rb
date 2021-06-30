# frozen_string_literal: true

require 'cancan/matchers'

describe Organization do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'organization admin' do
      let!(:organization) { create(:organization, :with_organization_admin) }
      let!(:other_organization) { create(:organization) }
      let(:user) { organization.organization_admins.first }

      it 'can read for organization that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true
          },
          organization
        )
      end

      it 'can\'t read, invite_organization_admin other organization' do
        expect(subject).to not_have_abilities(
          %i[read invite_organization_admin],
          other_organization
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'e-intervention admin' do
      let!(:organization) { create(:organization, :with_e_intervention_admin) }
      let!(:other_organization) { create(:organization) }
      let(:user) { organization.e_intervention_admins.first }

      it 'can read for organization that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true, update: true, invite_organization_admin: true, add: false, delete: false
          },
          organization
        )
      end

      it 'can\'t read, invite_organization_admin other organization' do
        expect(subject).to not_have_abilities(
          %i[manage invite_organization_admin],
          other_organization
        )
      end
    end

    context 'user can\'t read, invite_organization_admin of any organization' do
      %i[team_admin researcher participant guest].each do |role|
        context "current user is #{role}" do
          let(:user) { build_stubbed(:user, :confirmed, role) }

          it do
            expect(subject).to not_have_abilities(
              %i[read create update destroy invite_e_intervention_admin],
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

      it 'return all organizations' do
        expect(subject).to include(organization1, organization2)
      end
    end

    context 'organization_admin' do
      let!(:other_organization) { create(:organization) }
      let!(:user) { create(:user, :confirmed, :organization_admin, :with_organization) }

      it 'return all organization_admin\'s organizations' do
        expect(subject).to include(user.organizable).and not_include(other_organization)
      end
    end
  end
end

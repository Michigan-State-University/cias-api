# frozen_string_literal: true

require 'cancan/matchers'

describe SmsPlan do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:resource) { create(:sms_plan, session: create(:session, intervention: intervention)) }
      let(:user) { collaborator }

      it_behaves_like 'collaborator has expected access to resource'
    end

    context 'team admin' do
      let!(:user) { create(:user, :confirmed, :team_admin) }
      let!(:team) { create(:team, team_admin: user) }
      let!(:intervention1) { create(:intervention, user: user) }
      let!(:session1) { create(:session, intervention: intervention1) }
      let!(:sms_plan1) { create(:sms_plan, session: session1) }

      let!(:user2) { create(:user, :researcher, team: team) }
      let!(:intervention2) { create(:intervention, user: user2) }
      let!(:session2) { create(:session, intervention: intervention2) }
      let!(:sms_plan2) { create(:sms_plan, session: session2) }

      let!(:another_team) { create(:team, team_admin: user) }
      let!(:user3) { create(:user, :researcher, team: another_team) }
      let!(:intervention3) { create(:intervention, user: user3) }
      let!(:session3) { create(:session, intervention: intervention3) }
      let!(:sms_plan3) { create(:sms_plan, session: session3) }

      it { should have_abilities(:manage, described_class) }

      it 'can manage sms plans for sessions created by him' do
        expect(subject).to have_abilities({ manage: true }, sms_plan1)
      end

      it 'can manage sms plans for sessions created by users from his teams' do
        expect(subject).to have_abilities({ manage: true }, sms_plan2)
        expect(subject).to have_abilities({ manage: true }, sms_plan3)
      end
    end

    context 'researcher' do
      let(:user) { build_stubbed(:user, :confirmed, :researcher) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'participant' do
      let(:user) { build_stubbed(:user, :confirmed, :participant) }

      it do
        expect(subject).to not_have_abilities(
          %i[read create update destroy],
          described_class
        )
      end
    end

    context 'guest' do
      let(:user) { build_stubbed(:user, :confirmed, :guest) }

      it do
        expect(subject).to not_have_abilities(
          %i[read create update destroy],
          described_class
        )
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    let(:session1) { create(:session) }
    let(:session2) { create(:session) }
    let!(:sms_plan1) { create(:sms_plan, session: session1) }
    let!(:sms_plan2) { create(:sms_plan, session: session2) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all sms plans' do
        expect(subject).to include(sms_plan1, sms_plan2)
      end
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:sms_plan) { create(:sms_plan, session: create(:session, intervention: intervention)) }
      let(:user) { collaborator }

      it 'can access all sms plans' do
        expect(subject).to include(sms_plan).and not_include(sms_plan1, sms_plan2)
      end
    end

    context 'researcher' do
      let!(:user) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention, user: user) }
      let(:session1) { create(:session, intervention: intervention) }

      it 'can access for sms plan connected with session of intervention created by researcher' do
        expect(subject).to include(sms_plan1)
        expect(subject).not_to include(sms_plan2)
      end
    end

    context 'team admin' do
      let(:team) { create(:team) }
      let!(:user) { team.team_admin }
      let(:team_intervention) { create(:intervention, user: user) }

      let(:session1) { create(:session, intervention: team_intervention) }

      it 'can access for sms plan connected with session of intervention from his team' do
        expect(subject).to include(sms_plan1)
        expect(subject).not_to include(sms_plan2)
      end
    end
  end
end

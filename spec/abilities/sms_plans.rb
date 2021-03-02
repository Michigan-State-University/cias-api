# frozen_string_literal: true

require 'cancan/matchers'

describe SmsPlan do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let(:user) { build_stubbed(:user, :confirmed, :team_admin) }

      it { should have_abilities(:manage, described_class) }
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

    let(:session_1) { create(:session) }
    let(:session_2) { create(:session) }
    let!(:sms_plan_1) { create(:sms_plan, session: session_1) }
    let!(:sms_plan_2) { create(:sms_plan, session: session_2) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all sms plans' do
        expect(subject).to include(sms_plan_1, sms_plan_2)
      end
    end

    context 'researcher' do
      let!(:user) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention, user: user) }
      let(:session_1) { create(:session, intervention: intervention) }

      it 'can access for sms plan connected with session of intervention created by researcher' do
        expect(subject).to include(sms_plan_1)
        expect(subject).not_to include(sms_plan_2)
      end
    end

    context 'team admin' do
      let(:team) { create(:team, :with_team_admin) }
      let!(:user) { team.team_admin }
      let(:team_intervention) { create(:intervention, user: user) }


      let(:session_1) { create(:session, intervention: team_intervention) }

      it 'can access for sms plan connected with session of intervention from his team' do
        expect(subject).to include(sms_plan_1)
        expect(subject).not_to include(sms_plan_2)
      end
    end
  end
end

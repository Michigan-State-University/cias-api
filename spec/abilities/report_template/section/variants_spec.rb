# frozen_string_literal: true

require 'cancan/matchers'

describe ReportTemplate::Section::Variant do
  let_it_be(:team1) { create(:team) }
  let_it_be(:team2) { create(:team) }
  let_it_be(:team3) { create(:team, team_admin: team1.team_admin) }
  let_it_be(:team1_researcher) { create(:user, :confirmed, :researcher, team_id: team1.id) }
  let_it_be(:team2_researcher) { create(:user, :confirmed, :researcher, team_id: team2.id) }
  let_it_be(:team3_researcher) { create(:user, :confirmed, :researcher, team_id: team3.id) }
  let_it_be(:team1_intervention1) { create(:intervention, user_id: team1.team_admin.id) }
  let_it_be(:team1_intervention2) { create(:intervention, user_id: team1_researcher.id) }
  let_it_be(:team2_intervention1) { create(:intervention, user_id: team2.team_admin.id) }
  let_it_be(:team2_intervention2) { create(:intervention, user_id: team2_researcher.id) }
  let_it_be(:team3_intervention1) { create(:intervention, user_id: team3.team_admin.id) }
  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      team1_session1 = create(:session, intervention: team1_intervention1)
      team1_session2 = create(:session, intervention: team1_intervention2)
      team2_session1 = create(:session, intervention: team2_intervention1)
      team2_session2 = create(:session, intervention: team2_intervention2)
      team3_session1 = create(:session, intervention: team3_intervention1)

      team1_report_template1 = create(:report_template, session: team1_session1)
      team1_report_template2 = create(:report_template, session: team1_session2)
      team2_report_template1 = create(:report_template, session: team2_session1)
      team2_report_template2 = create(:report_template, session: team2_session2)
      team3_report_template1 = create(:report_template, session: team3_session1)

      team1_report_section1 = create(:report_template_section, report_template: team1_report_template1)
      team1_report_section2 = create(:report_template_section, report_template: team1_report_template2)
      team2_report_section1 = create(:report_template_section, report_template: team2_report_template1)
      team2_report_section2 = create(:report_template_section, report_template: team2_report_template2)
      team3_report_section1 = create(:report_template_section, report_template: team3_report_template1)

      @team1_report_variant1 =
        create(:report_template_section_variant, report_template_section: team1_report_section1)
      @team1_report_variant2 =
        create(:report_template_section_variant, report_template_section: team1_report_section2)
      @team2_report_variant1 =
        create(:report_template_section_variant, report_template_section: team2_report_section1)
      @team2_report_variant2 =
        create(:report_template_section_variant, report_template_section: team2_report_section2)
      @team3_report_variant1 =
        create(:report_template_section_variant, report_template_section: team3_report_section1)
    end
  end

  let(:team1_report_variant1) { @team1_report_variant1 }
  let(:team1_report_variant2) { @team1_report_variant2 }
  let(:team2_report_variant1) { @team2_report_variant1 }
  let(:team2_report_variant2) { @team2_report_variant2 }
  let(:team3_report_variant1) { @team3_report_variant1 }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can manage report section\'s variant of the user belonging to his team' do
        expect(subject).to have_abilities({ manage: true }, team1_report_variant1)
        expect(subject).to have_abilities({ manage: true }, team3_report_variant1)
        expect(subject).to have_abilities(
          { create: false },
          described_class.new(
            report_template_section_id: team2_report_variant2.report_template_section_id
          )
        )
      end

      it 'can manage his report section\'s variant' do
        expect(subject).to have_abilities({ manage: true }, team1_report_variant2)
      end

      it 'can\'t manage report section\'s variant of users from another team' do
        expect(subject).to have_abilities({ manage: false }, team2_report_variant1)
      end
    end

    context 'researcher' do
      let(:user) { team1_researcher }

      it 'can manage report section\'s variant of the session that belongs to him' do
        expect(subject).to have_abilities({ manage: true }, team1_report_variant2)
      end

      it 'can\'t manage report section\'s variant of other users' do
        expect(subject).to have_abilities({ manage: false }, team1_report_variant1)
        expect(subject).to have_abilities({ manage: false }, team2_report_variant1)
      end

      it 'can\'t create report template section in other users session' do
        expect(subject).to have_abilities(
          { create: false },
          described_class.new(
            report_template_section_id: team2_report_variant1.report_template_section_id
          )
        )
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all report template section variants' do
        expect(subject).to include(
          team1_report_variant1, team1_report_variant2, team2_report_variant1, team2_report_variant2
        )
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only report template section variants from his team' do
        expect(subject).to include(team1_report_variant1, team1_report_variant2, team3_report_variant1).and \
          not_include(team2_report_variant1, team2_report_variant2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only report template section variants from his team' do
        expect(subject).to include(team2_report_variant1, team2_report_variant2).and \
          not_include(team1_report_variant1, team1_report_variant2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only his report template section variants' do
        expect(subject).to include(team1_report_variant2).and \
          not_include(team1_report_variant1, team2_report_variant1, team2_report_variant2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'can\'t access any report template section variants' do
        expect(subject).not_to include(
          team1_report_variant1, team1_report_variant2, team2_report_variant1, team2_report_variant2
        )
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access any report template section variants' do
        expect(subject).not_to include(
          team1_report_variant1, team1_report_variant2, team2_report_variant1, team2_report_variant2
        )
      end
    end
  end
end

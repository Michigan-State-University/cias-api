# frozen_string_literal: true

require 'cancan/matchers'

describe ReportTemplate do
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
  let_it_be(:team3_intervention1) { create(:intervention, user_id: team3_researcher.id) }
  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      team1_session1 = create(:session, intervention: team1_intervention1)
      team1_session2 = create(:session, intervention: team1_intervention2)
      team2_session1 = create(:session, intervention: team2_intervention1)
      team2_session2 = create(:session, intervention: team2_intervention2)
      team3_session1 = create(:session, intervention: team3_intervention1)

      @team1_report_template1 = create(:report_template, session: team1_session1)
      @team1_report_template2 = create(:report_template, session: team1_session2)
      @team2_report_template1 = create(:report_template, session: team2_session1)
      @team2_report_template2 = create(:report_template, session: team2_session2)
      @team3_report_template1 = create(:report_template, session: team3_session1)
    end
  end

  let(:team1_report_template1) { @team1_report_template1 }
  let(:team1_report_template2) { @team1_report_template2 }
  let(:team2_report_template1) { @team2_report_template1 }
  let(:team2_report_template2) { @team2_report_template2 }
  let(:team3_report_template1) { @team3_report_template1 }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'e-intervention admin' do
      let(:user) { build_stubbed(:user, :confirmed, :e_intervention_admin) }

      it { should have_abilities(:read, described_class) }
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:resource) { create(:report_template, session: create(:session, intervention: intervention)) }
      let(:user) { collaborator }

      it_behaves_like 'collaborator has expected access to resource'
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can manage report_template of the user belonging to his team' do
        expect(subject).to have_abilities({ manage: true, generate_pdf_preview: true }, team1_report_template1)
        expect(subject).to have_abilities({ manage: true, generate_pdf_preview: true }, team3_report_template1)
        expect(subject).to have_abilities(
          { create: false },
          described_class.new(session_id: team2_intervention2.sessions.first.id)
        )
      end

      it 'can manage his report_template' do
        expect(subject).to have_abilities({ manage: true, generate_pdf_preview: true }, team1_report_template2)
      end

      it 'can\'t manage report_template of users from another team' do
        expect(subject).to have_abilities({ manage: false }, team2_report_template1)
      end
    end

    context 'researcher' do
      let(:user) { team1_researcher }

      it 'can manage report_template of the session that belongs to him' do
        expect(subject).to have_abilities({ manage: true, generate_pdf_preview: true }, team1_report_template2)
      end

      it 'can\'t manage report_template of other users' do
        expect(subject).to have_abilities({ manage: false, generate_pdf_preview: false }, team1_report_template1)
        expect(subject).to have_abilities({ manage: false, generate_pdf_preview: false }, team2_report_template1)
      end

      it 'can\'t create report template in other users session' do
        expect(subject).to have_abilities(
          { create: false },
          described_class.new(session_id: team2_intervention2.sessions.first.id)
        )
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all report templates' do
        expect(subject).to include(
          team1_report_template1, team1_report_template2, team2_report_template1, team2_report_template2
        )
      end
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:report_template) { create(:report_template, session: create(:session, intervention: intervention)) }
      let(:user) { collaborator }

      it do
        expect(subject).to include(report_template).and not_include(
          team1_report_template1, team1_report_template2, team2_report_template1, team2_report_template2
        )
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only report templates from his team' do
        expect(subject).to include(team1_report_template1, team1_report_template2, team3_report_template1).and \
          not_include(team2_report_template1, team2_report_template2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only report templates from his team' do
        expect(subject).to include(team2_report_template1, team2_report_template2).and \
          not_include(team1_report_template1, team1_report_template2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only his report templates' do
        expect(subject).to include(team1_report_template2).and \
          not_include(team1_report_template1, team2_report_template1, team2_report_template2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'can\'t access any report templates' do
        expect(subject).not_to include(
          team1_report_template1, team1_report_template2, team2_report_template1, team2_report_template2
        )
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access any report templates' do
        expect(subject).not_to include(
          team1_report_template1, team1_report_template2, team2_report_template1, team2_report_template2
        )
      end
    end
  end
end

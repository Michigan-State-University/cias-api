# frozen_string_literal: true

require 'cancan/matchers'

describe DownloadedReport do
  let!(:team1) { create(:team) }
  let!(:team2) { create(:team) }
  let!(:team3) { create(:team, team_admin: team1.team_admin) }

  let!(:team1_researcher) { create(:user, :confirmed, :researcher, team_id: team1.id) }
  let!(:team3_researcher) { create(:user, :confirmed, :researcher, team_id: team3.id) }

  let!(:team1_generated_report1) do
    create(:generated_report, user_session:
      create(:user_session, session:
        create(:session, intervention:
          create(:intervention, user_id: team1.team_admin.id))))
  end

  let!(:team1_generated_report2) do
    create(:generated_report, user_session:
      create(:user_session, session:
        create(:session, intervention:
          create(:intervention, user_id: team1_researcher.id))))
  end

  let!(:team2_generated_report1) do
    create(:generated_report, user_session:
      create(:user_session, session:
        create(:session, intervention:
          create(:intervention, user_id: team2.team_admin.id))))
  end

  let!(:team3_generated_report1) do
    create(:generated_report, user_session:
      create(:user_session, session:
        create(:session, intervention:
          create(:intervention, user_id: team3_researcher.id))))
  end

  context 'abilities' do
    subject(:ability) { Ability.new(user) }

    let(:team1_downloaded_report1) { create(:downloaded_report, generated_report: team1_generated_report1, user_id: user.id) }
    let(:team1_downloaded_report2) { create(:downloaded_report, generated_report: team1_generated_report2, user_id: user.id) }
    let(:team2_downloaded_report1) { create(:downloaded_report, generated_report: team2_generated_report1, user_id: user.id) }
    let(:team3_downloaded_report1) { create(:downloaded_report, generated_report: team3_generated_report1, user_id: user.id) }

    let(:third_party_report) { create(:generated_report, :third_party, third_party_id: user.id) }
    let(:participant_report) { create(:generated_report, :participant, participant_id: user.id) }

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can mark as downloaded report generated for the user session for his team member session' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report2)
        expect(subject).to have_abilities({ create: true }, team3_downloaded_report1)
      end

      it 'can mark his generated report' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report1)
      end

      it 'can\'t mark generated report for the user\'s session, when session belongs to the researcher from another team' do
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
      end
    end

    context 'researcher' do
      let(:user) { team1_researcher }

      it 'can mark generated report for the session that belongs to him' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report2)
      end

      it 'can\'t mark generated report for the sessions that belong to other researchers' do
        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
      end
    end

    context 'participant' do
      let(:user) { create(:user, :confirmed, :participant) }

      let!(:shown_participant_report_downloaded) do
        create(:downloaded_report, user_id: user.id, generated_report: create(:generated_report, :participant,
                                                                              participant_id: user.id))
      end
      let!(:third_party_report_downloaded) do
        create(:downloaded_report, generated_report: third_party_report, user_id: user.id)
      end
      let!(:not_shown_participant_report_downloaded) do
        create(:downloaded_report, user_id: user.id, generated_report: create(:generated_report, :participant))
      end

      it 'can mark only his report if the report kind is \'participant\' and report is shown to participant' do
        expect(subject).to have_abilities({ create: true }, shown_participant_report_downloaded)

        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, third_party_report_downloaded)
        expect(subject).to have_abilities({ create: false }, not_shown_participant_report_downloaded)
      end
    end

    context 'third party' do
      let(:user) { create(:user, :confirmed, :third_party) }

      let!(:third_party_report_downloaded) do
        create(:downloaded_report, generated_report: third_party_report, user_id: user.id)
      end
      let!(:participant_report_downloaded) do
        create(:downloaded_report, generated_report: participant_report, user_id: user.id)
      end
      let!(:other_third_party_report_downloaded) do
        create(:downloaded_report, user_id: user.id, generated_report: create(:generated_report, :third_party))
      end

      it 'can mark only his report if the report kind is \'third_party\' and report is shared with him' do
        expect(subject).to have_abilities({ create: true }, third_party_report_downloaded)

        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, participant_report_downloaded)
        expect(subject).to have_abilities({ create: false }, other_third_party_report_downloaded)
      end
    end
  end
end

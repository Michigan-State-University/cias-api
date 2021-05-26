# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::GenerateUserSessionReports do
  subject { described_class.call(user_session) }

  let!(:current_v1_user) { create(:user, :confirmed, :guest) }
  let!(:session) { create(:session) }
  let!(:third_party_report_template) { create(:report_template, :third_party, session: session) }
  let!(:participant_report_template) { create(:report_template, :participant, session: session) }
  let!(:user_session) { create(:user_session, user: current_v1_user, session: session) }
  let!(:all_var_values) { user_session.all_var_values }
  let(:dentaku_calculator) { Dentaku::Calculator.new }

  before do
    allow(Dentaku::Calculator).to receive(:new).and_return(dentaku_calculator)
  end

  context 'there are report templates for the session' do
    let(:dentaku_service) { Calculations::DentakuService.new(all_var_values) }

    before do
      allow(Calculations::DentakuService).to receive(:new).with(all_var_values).and_return(dentaku_service)
    end

    it 'runs GeneratedReports::Create service for each report template' do
      expect(dentaku_calculator).not_to receive(:store)
      expect(V1::GeneratedReports::Create).to receive(:call).
        with(third_party_report_template, user_session, dentaku_service)
      expect(V1::GeneratedReports::Create).to receive(:call).
        with(participant_report_template, user_session, dentaku_service)
      expect(V1::GeneratedReports::ShareToThirdParty).to receive(:call).with(user_session)
      expect(V1::GeneratedReports::ShareToParticipant).to receive(:call).with(user_session)
      subject
    end
  end

  context 'when there are some variables in user sessions answers' do
    let!(:answer1) do
      create(:answer_single, user_session: user_session, body: { data: [{ var: 'temp', value: '10' }] })
    end
    let!(:answer2) do
      create(:answer_single, user_session: user_session, body: { data: [{ var: 'temp2', value: '20' }] })
    end
    let!(:reloaded_values) { user_session.reload.all_var_values }

    it 'stores all the variables in the dentaku calculator memory' do
      expect(dentaku_calculator).to receive(:store).with('temp' => '10', 'temp2' => '20')
      expect(V1::GeneratedReports::Create).to receive(:call).twice
      subject
    end
  end

  context 'there aren\'n any report templates for the session' do
    before do
      ReportTemplate.destroy_all
    end

    it 'does not run service to create generated report' do
      expect(dentaku_calculator).not_to receive(:store)
      expect(V1::GeneratedReports::Create).not_to receive(:call)
      subject
    end
  end

  context 'user is preview_session' do
    let!(:current_v1_user) { create(:user, :confirmed, :preview_session) }

    it 'does not run service to create generated report' do
      expect(dentaku_calculator).not_to receive(:store)
      expect(V1::GeneratedReports::Create).not_to receive(:call)
      subject
    end
  end
end

# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::GenerateUserSessionReports do
  subject { described_class.call(user_session) }

  let!(:current_v1_user) { create(:user, :confirmed, :guest) }
  let!(:session) { create(:session) }
  let!(:report_template1) { create(:report_template, session: session) }
  let!(:report_template2) { create(:report_template, session: session) }
  let!(:user_session) { create(:user_session, user: current_v1_user, session: session) }
  let(:dentaku_calculator) { Dentaku::Calculator.new }

  before do
    allow(Dentaku::Calculator).to receive(:new).and_return(dentaku_calculator)
  end

  context 'there are report templates for the session' do
    it 'runs GeneratedReports::Create service for each report template' do
      expect(dentaku_calculator).not_to receive(:store)
      expect(V1::GeneratedReports::Create).to receive(:call).
        with(report_template1, user_session, dentaku_calculator)
      expect(V1::GeneratedReports::Create).to receive(:call).
        with(report_template2, user_session, dentaku_calculator)
      subject
    end

    context 'when there are some variables in user sessions answers' do
      let!(:answer1) { create(:answer_single, user_session: user_session, body: { data: [{ var: 'temp', value: '10' }] }) }
      let!(:answer2) { create(:answer_single, user_session: user_session, body: { data: [{ var: 'temp2', value: '20' }] }) }

      it 'stores all the variables in the dentaku calculator memory' do
        expect(dentaku_calculator).to receive(:store).with('temp' => '10', 'temp2' => '20')
        expect(V1::GeneratedReports::Create).to receive(:call).twice
        subject
      end
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

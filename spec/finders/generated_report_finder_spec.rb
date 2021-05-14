# frozen_string_literal: true

RSpec.describe GeneratedReportFinder do
  subject { described_class.search(filter_params, current_user) }

  let(:filter_params) { {} }
  let(:current_user) { create(:user, :confirmed, :admin) }
  let!(:intervention) {create(:intervention, user: current_user)}
  let!(:session) {create(:session, intervention: intervention)}
  let!(:user_session) {create(:user_session, session: session)}
  let!(:participant_report) { create(:generated_report, :with_pdf_report, :participant, user_session: user_session) }
  let!(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, user_session: user_session) }

  context 'filter by :report_for' do
    context 'reports only for participant' do
      let(:filter_params) { { report_for: 'participant' } }

      it 'returns only generated reports for participant' do
        expect(subject).to include(participant_report).and \
          not_include(third_party_report)
      end
    end

    context 'reports only for third_party' do
      let(:filter_params) { { report_for: 'third_party' } }

      it 'returns only generated reports for participant' do
        expect(subject).to include(third_party_report).and \
          not_include(participant_report)
      end
    end
  end

  it 'ensures that accessible_by is used' do
    expect(GeneratedReport).to receive(:accessible_by).with(current_user.ability)
    subject
  end
end

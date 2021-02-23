# frozen_string_literal: true

RSpec.describe ReportTemplates::GeneratePdfPreviewJob, type: :job do
  subject { described_class.perform_now(report_template.id, user.id) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:report_template) { create(:report_template) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'call generate pdf preview service' do
    expect(V1::ReportTemplates::GeneratePdfPreview).to receive(:call).with(
      report_template,
      user
    )
    subject
  end
end

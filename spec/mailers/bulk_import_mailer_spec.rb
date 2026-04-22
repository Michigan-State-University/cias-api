# frozen_string_literal: true

RSpec.describe BulkImportMailer do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:result) do
    { total: 10, participants_created: 9, ra_completed: 5, ra_partial: 4, failed: 1 }
  end

  describe '#bulk_import_result' do
    subject(:mail) { described_class.bulk_import_result(researcher, intervention, result) }

    it 'sends to the researcher' do
      expect(mail.to).to eq([researcher.email])
    end

    it 'has the configured subject' do
      expect(mail.subject).to eq(I18n.t('bulk_import_mailer.bulk_import_result.subject'))
    end

    it 'renders the intervention name in the body' do
      expect(mail.body.encoded).to include(intervention.name)
    end

    it 'renders each counter from the result hash in the body' do
      body = mail.body.encoded
      expect(body).to include('9 participants created')
      expect(body).to include('5 RA sessions auto-completed')
      expect(body).to include('4 partially filled')
      expect(body).to include('1 failed')
      expect(body).to include('10 rows')
    end

    it 'does not include any per-row participant data' do
      # HIPAA: summary counts only, never emails/names/phones.
      body = mail.body.encoded
      expect(body).not_to include(researcher.email)
      expect(body).not_to match(/@predefined-participant\.true/)
    end
  end

  describe '#bulk_import_error' do
    subject(:mail) { described_class.bulk_import_error(researcher, intervention) }

    it 'sends to the researcher' do
      expect(mail.to).to eq([researcher.email])
    end

    it 'has the configured subject' do
      expect(mail.subject).to eq(I18n.t('bulk_import_mailer.bulk_import_error.subject'))
    end

    it 'renders the intervention name in the body' do
      expect(mail.body.encoded).to include(intervention.name)
    end

    it 'renders a generic error body with no per-row detail' do
      body = mail.body.encoded
      expect(body).to include('could not be processed')
      expect(body).not_to match(/@predefined-participant\.true/)
    end
  end
end

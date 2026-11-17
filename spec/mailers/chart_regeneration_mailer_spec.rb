# frozen_string_literal: true

RSpec.describe ChartRegenerationMailer do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let(:chart) { create(:chart, dashboard_section: dashboard_section, name: 'Readiness to change') }

  describe '#regeneration_complete' do
    subject(:mail) { described_class.regeneration_complete(user, chart) }

    it 'sends to the triggering user' do
      expect(mail.to).to eq([user.email])
    end

    it 'names the chart in the subject' do
      expect(mail.subject).to eq(
        I18n.t('chart_regeneration_mailer.complete.subject', chart_name: 'Readiness to change')
      )
    end

    it 'renders both an html and a text part' do
      expect(mail.body.parts.map { |part| part.content_type.split(';').first })
        .to contain_exactly('text/plain', 'text/html')
    end

    it 'names the chart in the body' do
      expect(mail.body.encoded).to include('Readiness to change')
    end

    # The body interpolates a name a researcher typed. It must not be compiled as ERB (the
    # `render inline:` idiom the clone templates use for their static copy would do exactly that)
    # and it must not be injected as raw HTML.
    context 'when the chart name contains markup' do
      let(:chart) { create(:chart, dashboard_section: dashboard_section, name: '<%= 7 * 6 %><b>x</b>') }

      it 'does not evaluate it' do
        expect(mail.body.parts.map { |part| part.body.decoded }.join).not_to include('42')
      end

      it 'escapes it in the html part' do
        html = mail.body.parts.find { |part| part.content_type.start_with?('text/html') }

        expect(html.body.encoded).to include('&lt;b&gt;')
        expect(html.body.encoded).not_to include('<b>x</b>')
      end
    end

    # The mailer is deliberately a dumb renderer: the `email_notification` guard lives in
    # RegenerateChartsJob, following the house convention, and is asserted there.
    it 'renders even for a user who has notifications switched off' do
      user.update!(email_notification: false)

      expect(mail.to).to eq([user.email])
    end
  end
end

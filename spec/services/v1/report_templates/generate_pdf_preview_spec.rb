# frozen_string_literal: true

RSpec.describe V1::ReportTemplates::GeneratePdfPreview do
  subject { described_class.call(report_template, current_v1_user) }

  let!(:current_v1_user) { create(:user, :confirmed, :admin) }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:section1) do
    create(:report_template_section, report_template: report_template)
  end
  let!(:section1_preview_variant) do
    create(:report_template_section_variant, report_template_section: section1, preview: true)
  end
  let!(:section1_variant) do
    create(:report_template_section_variant, report_template_section: section1, preview: false)
  end
  let!(:section2) do
    create(:report_template_section, report_template: report_template)
  end
  let!(:section2_preview_variant) do
    create(:report_template_section_variant, report_template_section: section2, preview: true)
  end
  let!(:section2_variant) do
    create(:report_template_section_variant, report_template_section: section2, preview: false)
  end

  let(:variants_to_preview) { [section1_preview_variant, section2_preview_variant] }
  let(:action_controller_double) { double(render_to_string: 'string') }
  let(:template_preview_mailer) { double(deliver_now: true) }
  let(:wicked_pdf_instance) { double(pdf_from_string: true) }

  before do
    allow(ActionController::Base).to receive(:new).and_return(action_controller_double)
    allow(WickedPdf).to receive(:new).and_return(wicked_pdf_instance)
  end

  context 'there are variants to preview' do
    context 'email notification enabled' do
      it 'runs mailer with created PDF preview' do
        expect(action_controller_double).to receive(:render_to_string).with(
          template: 'report_templates/report_preview.html.erb',
          locals: {
            report_template: report_template,
            variants: match_array(variants_to_preview)
          }
        )
        expect(action_controller_double).to receive(:render_to_string).with(
          template: 'report_templates/report_header.html.erb',
          locals: {
            report_template: report_template
          }
        )
        allow(wicked_pdf_instance).to receive(:pdf_from_string).and_return('PDF')
        allow(ReportTemplateMailer).to receive(:template_preview).with(
          email: current_v1_user.email,
          report_template: report_template,
          report_template_preview_pdf: 'PDF'
        ).and_return(template_preview_mailer)

        subject
      end
    end

    context 'email notification disabled' do
      it "don't run mailer" do
        expect(ReportTemplateMailer).not_to receive(:template_preview)
      end
    end
  end
end

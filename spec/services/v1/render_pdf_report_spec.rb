# frozen_string_literal: true

RSpec.describe V1::RenderPdfReport do
  subject { described_class.call(report_template: report_template, variants_to_generate: variants_to_generate) }

  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session, summary: summary_content) }
  let!(:section) { create(:report_template_section, report_template: report_template) }
  let!(:variant) do
    create(:report_template_section_variant,
           report_template_section: section,
           title: 'Test Section',
           content: variant_content)
  end
  let(:variants_to_generate) { [variant] }

  let(:summary_content) { '<p>This is a summary</p>' }
  let(:variant_content) { '<p>Simple content</p>' }

  let(:wicked_pdf_instance) { instance_double(WickedPdf) }

  before do
    allow(WickedPdf).to receive(:new).and_return(wicked_pdf_instance)
    allow(wicked_pdf_instance).to receive(:pdf_from_string).and_return('PDF_CONTENT')
  end

  describe '.call' do
    it 'generates a PDF with correct margins' do
      expect(wicked_pdf_instance).to receive(:pdf_from_string).with(
        anything,
        hash_including(
          margin: {
            top: 35,
            bottom: 20,
            right: 15,
            left: 15
          }
        )
      )
      subject
    end

    it 'includes header and footer in PDF options' do
      expect(wicked_pdf_instance).to receive(:pdf_from_string).with(
        anything,
        hash_including(
          header: { content: anything },
          footer: { content: anything }
        )
      )
      subject
    end

    context 'when content contains links with href attributes' do
      let(:variant_content) do
        '<p><strong style="background-color: rgb(204, 232, 204);">Hello, happy to be here. Click </strong>' \
          '<a href="https://google.com" rel="noopener noreferrer" target="_blank" ' \
          'style="background-color: rgb(204, 232, 204);"><strong>here</strong></a>' \
          '<strong style="background-color: rgb(204, 232, 204);"> to check the playlist </strong></p>'
      end

      it 'preserves href attributes in links' do
        subject

        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).to include('href="https://google.com"')
        expect(html_content).to include('rel="noopener noreferrer"')
        expect(html_content).to include('target="_blank"')
      end

      it 'does not strip anchor tags' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).to include('<a ')
        expect(html_content).to include('</a>')
      end
    end

    context 'when summary contains links with href attributes' do
      let(:summary_content) do
        '<p>Check out <a href="https://example.com" target="_blank" rel="noopener">this link</a> for more info</p>'
      end

      it 'preserves href attributes in summary links' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).to include('href="https://example.com"')
        expect(html_content).to include('target="_blank"')
        expect(html_content).to include('rel="noopener"')
      end
    end

    context 'when content has potentially unsafe attributes' do
      let(:variant_content) do
        '<p><a href="https://safe.com" onclick="alert(\'xss\')" data-custom="value">Click here</a></p>'
      end

      it 'strips unsafe attributes like onclick' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).not_to include('onclick')
        expect(html_content).to include('href="https://safe.com"')
      end

      it 'strips non-whitelisted attributes' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).not_to include('data-custom')
      end
    end

    context 'when content contains multiple variants' do
      let!(:variant2) do
        create(:report_template_section_variant,
               report_template_section: section,
               title: 'Second Section',
               content: '<p>Second content with <a href="https://example2.com">link</a></p>')
      end
      let(:variants_to_generate) { [variant, variant2] }

      it 'preserves href in all variants' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).to include('href="https://example2.com"')
        expect(html_content).to include('Second Section')
      end
    end

    context 'when content has class attributes' do
      let(:variant_content) do
        '<p class="ql-align-center"><strong>Centered content</strong></p>'
      end

      it 'preserves class attributes' do
        html_content = nil
        allow(wicked_pdf_instance).to receive(:pdf_from_string) do |html, _options|
          html_content = html
          'PDF_CONTENT'
        end

        described_class.call(report_template: report_template, variants_to_generate: variants_to_generate)

        expect(html_content).to include('class="ql-align-center"')
      end
    end
  end

  describe 'private methods' do
    let(:service_instance) { described_class.new(report_template, variants_to_generate) }

    describe '#report_template_html' do
      it 'renders the report_preview template' do
        action_controller = service_instance.send(:action_controller)

        expect(action_controller).to receive(:render_to_string).with(
          template: 'report_templates/report_preview',
          locals: {
            report_template: report_template,
            variants: variants_to_generate
          }
        )

        service_instance.send(:report_template_html)
      end
    end

    describe '#report_header_html' do
      it 'renders the report_header template' do
        action_controller = service_instance.send(:action_controller)

        expect(action_controller).to receive(:render_to_string).with(
          template: 'report_templates/report_header',
          locals: {
            report_template: report_template
          }
        )

        service_instance.send(:report_header_html)
      end
    end
  end
end

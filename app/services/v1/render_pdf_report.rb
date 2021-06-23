# frozen_string_literal: true

class V1::RenderPdfReport
  def self.call(report_template:, variants_to_generate:)
    new(report_template, variants_to_generate).call
  end

  def initialize(report_template, variants_to_generate)
    @action_controller = ActionController::Base.new
    @report_template = report_template
    @variants_to_generate = variants_to_generate
  end

  def call
    WickedPdf.new.pdf_from_string(
      report_template_html,
      margin: {
        top: 35,
        bottom: 20,
        right: 15,
        left: 15
      },
      header: {
        content: report_header_html
      },
      footer: {
          content: report_footer_html
      }
    )
  end

  private

  attr_reader :report_template, :variants_to_generate, :action_controller

  def report_template_html
    action_controller.render_to_string(
      template: 'report_templates/report_preview.html.erb',
      locals: {
        report_template: report_template,
        variants: variants_to_generate
      }
    )
  end

  def report_header_html
    action_controller.render_to_string(
      template: 'report_templates/report_header.html.erb',
      locals: {
        report_template: report_template
      }
    )
  end

  def report_footer_html
    action_controller.render_to_string(
        template: 'report_templates/report_footer.html.erb',
        locals: {
            datetime_content: "Completed on #{DateTime.now.to_s(:db)}"
        }
    )
  end
end

# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::Create do
  subject { described_class.call(report_template, user_session, dentaku_service) }

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      session = create(:session)
      @user_session = create(:user_session, session: session)
      @report_template = create(:report_template, session: session)
      section1 = create(:report_template_section, report_template: @report_template,
                                                  formula: 'var1+var2')
      section2 = create(:report_template_section, report_template: @report_template,
                                                  formula: 'var3-var4')
      @section1_variant1 = create(:report_template_section_variant, report_template_section: section1,
                                                                    formula_match: '=10')
      @section1_variant2 = create(:report_template_section_variant, report_template_section: section1,
                                                                    formula_match: '=20')
      @section2_variant1 = create(:report_template_section_variant, report_template_section: section2,
                                                                    formula_match: '<10')
      @section2_variant2 = create(:report_template_section_variant, report_template_section: section2,
                                                                    formula_match: '=10')
    end
  end

  let(:user_session) { @user_session }
  let(:report_template) { @report_template }
  let(:section1_variant1) { @section1_variant1 }
  let(:section1_variant2) { @section1_variant2 }
  let(:section2_variant1) { @section2_variant1 }
  let(:section2_variant2) { @section2_variant2 }
  let(:all_var_values) { { var1: 5, var2: 5, var3: 10, var4: 5 } }
  let(:dentaku_service) { Calculations::DentakuService.new(all_var_values) }
  let(:dentaku_calculator) { Dentaku::Calculator.new }

  before do
    allow(Dentaku::Calculator).to receive(:new).and_return(dentaku_calculator)
    dentaku_service.store_and_transform_values
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'when there are sections with variants' do
    let(:generated_report) { GeneratedReport.last }
    let!(:answer_receive_report_true) do
      create(:answer_name, user_session: user_session,
                           body: { data: [
                             { 'var' => '.:name:.', 'value' => { 'name' => '', 'phoneticName' => 'John' } }
                           ] })
    end

    before do
      section1_variant1.update(content: "Hello .:name:., #{section1_variant1.content}")
      section2_variant1.update(content: "Hello .:name:.. #{section2_variant1.content}")
    end

    it 'creates generated report with proper attributes and attachments' do
      expect(V1::RenderPdfReport).to receive(:call).with(
        report_template: report_template,
        variants_to_generate: [
          variant_with_content('Hello Participant,'),
          variant_with_content('Hello Participant.')
        ]
      ).and_return('PDF TEMPLATE')

      expect { subject }.to change(GeneratedReport, :count).by(1).and \
        change(ActiveStorage::Attachment, :count).by(1).and \
          change(ActiveStorage::Blob, :count).by(1)
      expect(generated_report).to have_attributes(
        name: include("Report #{Time.current.strftime('%m_%d_%Y_%H_%M')}"),
        user_session_id: user_session.id,
        report_template_id: report_template.id,
        report_for: report_template.report_for
      )

      expect(generated_report.pdf_report.attachment.blob).to have_attributes(
        content_type: 'application/pdf'
      )
    end

    context 'third party report' do
      before do
        report_template.update(report_for: 'third_party')
      end

      it 'shares report to third party' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')
        subject
      end
    end

    context 'participant report' do
      before do
        report_template.update(report_for: 'participant')
      end

      it 'does not share report to third party' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')
        subject
      end
    end

    context 'when some of variables values are missing' do
      let(:all_var_values) { { var1: 5, var2: 5 } }

      it 'creates generated report with proper attributes and attachments' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')

        expect { subject }.to change(GeneratedReport, :count).by(1)

        expect(dentaku_calculator.memory).to include('var3' => 0, 'var4' => 0)
      end
    end

    context 'when name variable is used' do
      let!(:answer_receive_report_true) do
        create(:answer_name, user_session: user_session,
                             body: { data: [
                               { 'var' => '.:name:.', 'value' => { 'name' => 'John', 'phoneticName' => 'John' } }
                             ] })
      end

      before do
        section1_variant1.update(content: "Hello .:name:., #{section1_variant1.content}")
        section2_variant1.update(content: "Hello .:name:.. #{section2_variant1.content}")
      end

      it 'replace name variable with name variable value in variants contents' do
        expect(V1::RenderPdfReport).to receive(:call).with(
          report_template: report_template,
          variants_to_generate: [
            variant_with_content('Hello John,'),
            variant_with_content('Hello John.')
          ]
        ).and_return('PDF TEMPLATE')

        subject
      end
    end
  end

  context 'when there are no variants that meet formula' do
    let(:all_var_values) { { var1: 50, var2: 50, var3: 100, var4: 5 } }

    it 'does not create new generated report' do
      expect { subject }.to avoid_changing(GeneratedReport, :count).and \
        avoid_changing(ActiveStorage::Attachment, :count).and \
          avoid_changing(ActiveStorage::Blob, :count)
    end
  end

  context 'when there are no sections in the report' do
    let!(:report_template) { create(:report_template) }

    it 'does not create new generated report' do
      expect { subject }.to avoid_changing(GeneratedReport, :count).and \
        avoid_changing(ActiveStorage::Attachment, :count).and \
          avoid_changing(ActiveStorage::Blob, :count)
    end
  end
end

# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::Create do
  subject { described_class.call(report_template, user_session, dentaku_calculator) }

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

  context 'when there are sections with variants' do
    let(:dentaku_calculator) { Dentaku::Calculator.new.store(var1: 5, var2: 5, var3: 10, var4: 5) }
    let(:generated_report) { GeneratedReport.last }

    it 'creates generated report with proper attributes and attachments' do
      expect(V1::RenderPdfReport).to receive(:call).with(
        report_template: report_template,
        variants_to_generate: [section1_variant1, section2_variant1]
      ).and_return('PDF TEMPLATE')

      expect { subject }.to change(GeneratedReport, :count).by(1).and \
        change(ActiveStorage::Attachment, :count).by(1).and \
          change(ActiveStorage::Blob, :count).by(1)

      expect(generated_report).to have_attributes(
        name: include('Report'),
        user_session_id: user_session.id,
        report_template_id: report_template.id,
        report_for: report_template.report_for,
        shown_for_participant: false
      )

      expect(generated_report.pdf_report.attachment.blob).to have_attributes(
        content_type: 'application/pdf'
      )
    end

    context 'when some of variables values are missing' do
      let(:dentaku_calculator) { Dentaku::Calculator.new.store(var1: 5, var2: 5) }

      it 'creates generated report with proper attributes and attachments' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')

        expect { subject }.to change(GeneratedReport, :count).by(1)

        expect(dentaku_calculator.memory).to include('var3' => 0, 'var4' => 0)
      end
    end

    context 'when display participant voted for not receiving report' do
      let(:dentaku_calculator) { Dentaku::Calculator.new }
      let!(:answer_receive_report_false) do
        create(:answer_participant_report, user_session: user_session,
                                           body: { data: [{ value: { receive_report: false } }] })
      end

      it 'creates generated report with show_for_participant set to false' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')
        subject
        expect(generated_report).to have_attributes(
          shown_for_participant: false
        )
      end
    end

    context 'when display participant voted for receiving report' do
      let(:dentaku_calculator) { Dentaku::Calculator.new }
      let!(:answer_receive_report_true) do
        create(:answer_participant_report, user_session: user_session,
                                           body: { data: [{ value: { receive_report: true } }] })
      end

      it 'creates generated report with show_for_participant set to true' do
        expect(V1::RenderPdfReport).to receive(:call).and_return('PDF TEMPLATE')
        subject
        expect(generated_report).to have_attributes(
          shown_for_participant: true
        )
      end
    end

    context 'when name variable is used' do
      let(:dentaku_calculator) { Dentaku::Calculator.new.store(var1: 5, var2: 5, var3: 10, var4: 5) }
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
    let(:dentaku_calculator) { Dentaku::Calculator.new.store(var1: 50, var2: 50, var3: 100, var4: 5) }

    it 'does not create new generated report' do
      expect { subject }.to avoid_changing(GeneratedReport, :count).and \
        avoid_changing(ActiveStorage::Attachment, :count).and \
          avoid_changing(ActiveStorage::Blob, :count)
    end
  end

  context 'when there are no sections in the report' do
    let(:dentaku_calculator) { Dentaku::Calculator.new }
    let!(:report_template) { create(:report_template) }

    it 'does not create new generated report' do
      expect { subject }.to avoid_changing(GeneratedReport, :count).and \
        avoid_changing(ActiveStorage::Attachment, :count).and \
          avoid_changing(ActiveStorage::Blob, :count)
    end
  end
end

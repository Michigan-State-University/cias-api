# frozen_string_literal: true

RSpec.describe V1::Intervention::ExportData do
  let!(:intervention) { create(:intervention_with_logo, shared_to: 'registered') }
  let!(:accesses) do
    InterventionAccess.create!([
                                 { email: 'walter.white@gmail.com', intervention: intervention },
                                 { email: 'jessie.pinkman@gmail.com', intervention: intervention },
                                 { email: 'gus.fring@gmail.com', intervention: intervention }
                               ])
  end
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question) { create(:question_single, :branching_to_question, :narrator_blocks_types, question_group: question_group) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let!(:sms_plan_variants) { create(:sms_plan_variant, sms_plan: sms_plan) }
  let!(:report_template) { create(:report_template, :with_sections, :with_logo, session: session) }
  let!(:report_template_section) { report_template.sections.first }
  let!(:report_template_variant) { report_template_section.variants.first }
  let(:result) { described_class.call(intervention) }

  context 'correctly exports data' do
    it 'returns correct intervention data' do
      expect(result).to include(
        additional_text: intervention.additional_text,
        language_name: intervention.google_language.language_name,
        original_text: intervention.original_text,
        language_code: intervention.google_language.language_code,
        name: "Imported #{intervention.name}",
        quick_exit: intervention.quick_exit,
        type: intervention.type,
        shared_to: intervention.shared_to,
        logo: {
          extension: intervention.logo_blob.filename.extension,
          content_type: intervention.logo.content_type,
          description: intervention.logo.description,
          file: Base64.encode64(intervention.logo.download)
        },
        version: '1'
      )
    end

    it 'returns correct access e-mails in intervention' do
      expect(result[:intervention_accesses]).to include(
        { email: 'walter.white@gmail.com', version: '1' },
        { email: 'jessie.pinkman@gmail.com', version: '1' },
        { email: 'gus.fring@gmail.com', version: '1' }
      )
    end

    it 'returns correct session data inside intervention' do
      expect(result[:sessions][0]).to include(
        body: session.body,
        days_after_date_variable_name: session.days_after_date_variable_name,
        estimated_time: session.estimated_time,
        formulas: session.formulas,
        voice_type: session.google_tts_voice.voice_type,
        voice_label: session.google_tts_voice.voice_label,
        language_code: session.google_tts_voice.language_code,
        name: session.name,
        original_text: session.original_text,
        position: session.position,
        schedule: session.schedule,
        schedule_at: session.schedule_at,
        schedule_payload: session.schedule_payload,
        settings: session.settings,
        type: session.type,
        variable: session.variable,
        version: '1'
      )
    end

    it 'returns correct question group data inside session' do
      expect(result[:sessions][0][:question_groups][0]).to include(
        title: question_group.title,
        position: question_group.position,
        type: question_group.type,
        version: '1'
      )
    end

    it 'returns correct question in question group' do
      expect(result[:sessions][0][:question_groups][0][:questions][0]).to include(
        type: question.type,
        settings: question.settings,
        position: question.position,
        title: question.title,
        subtitle: question.subtitle,
        narrator: question.narrator,
        video_url: question.video_url,
        formulas: question.formulas,
        body: question.body,
        original_text: question.original_text,
        duplicated: true,
        image: {
          extension: question.image.filename.extension,
          content_type: question.image.content_type,
          description: question.image.description,
          file: Base64.encode64(question.image.download)
        },
        version: '1'
      )
    end

    it 'returns correct sms plan data inside session' do
      expect(result[:sessions][0][:sms_plans][0]).to include(
        name: sms_plan.name,
        schedule: sms_plan.schedule,
        schedule_payload: sms_plan.schedule_payload,
        frequency: sms_plan.frequency,
        end_at: sms_plan.end_at,
        formula: sms_plan.formula,
        no_formula_text: sms_plan.no_formula_text,
        is_used_formula: sms_plan.is_used_formula,
        original_text: sms_plan.original_text,
        type: sms_plan.type,
        include_first_name: sms_plan.include_first_name,
        include_last_name: sms_plan.include_last_name,
        include_phone_number: sms_plan.include_phone_number,
        include_email: sms_plan.include_email,
        version: '1'
      )
    end

    it 'returns correct sms plan variant data inside sms plan' do
      expect(result[:sessions][0][:sms_plans][0][:variants][0]).to include(
        formula_match: sms_plan_variants.formula_match,
        content: sms_plan_variants.content,
        original_text: sms_plan_variants.original_text,
        position: sms_plan_variants.position,
        version: '1'
      )
    end

    it 'returns correct report template data inside session' do
      expect(result[:sessions][0][:report_templates][0]).to include(
        name: report_template.name,
        report_for: report_template.report_for,
        summary: report_template.summary,
        original_text: report_template.original_text,
        logo: {
          extension: report_template.logo_blob.filename.extension,
          content_type: report_template.logo.content_type,
          description: report_template.logo.description,
          file: Base64.encode64(report_template.logo.download)
        },
        version: '1'
      )
    end

    it 'returns correct report template section data inside report template' do
      expect(result[:sessions][0][:report_templates][0][:sections][0]).to include(
        formula: report_template_section.formula,
        position: report_template_section.position,
        version: '1'
      )
    end

    it 'returns correct report template section variant data inside report template section' do
      expect(result[:sessions][0][:report_templates][0][:sections][0][:variants][0]).to include(
        preview: report_template_variant.preview,
        formula_match: report_template_variant.formula_match,
        title: report_template_variant.title,
        content: report_template_variant.content,
        original_text: report_template_variant.original_text,
        image: {
          extension: report_template_variant.image.filename.extension,
          content_type: report_template_variant.image.content_type,
          description: report_template_variant.image.description,
          file: Base64.encode64(report_template_variant.image.download)
        },
        version: '1'
      )
    end
  end
end

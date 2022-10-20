# frozen_string_literal: true

namespace :interventions do
  desc 'Fix report templates in existing interventions'
  task fix_report_templates_in_questions: :environment do
    questions = Question::ThirdParty.all

    @fixed_question = 0
    p 'START ANALYZING QUESTIONS...'
    questions.find_each.with_index do |question, index|
      check_and_report_templates(question)

      p "#{index+1} out of #{questions.count} questions were checked"
    end
    p "FINISH! #{@fixed_question} incorrect report templates were fixed"
  end

  private

  def check_and_report_templates(question)
    question.body_data.each do |block|
      remove_nonexistent_reports_from_block(block)
    end

    question.save!
  end

  def remove_nonexistent_reports_from_block(block)
    report_template_ids = block['report_template_ids']
    return if report_template_ids.blank?

    report_templates = ReportTemplate.where(id: report_template_ids)
    return if report_templates.size == report_template_ids.size

    block['report_template_ids'] = report_templates.map(&:id)
    @fixed_question = @fixed_question + 1
  end
end

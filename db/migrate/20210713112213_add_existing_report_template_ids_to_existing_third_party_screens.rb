# frozen_string_literal: true

class AddExistingReportTemplateIdsToExistingThirdPartyScreens < ActiveRecord::Migration[6.0]
  def self.up
    Question::ThirdParty.all.each do |third_party_question|
      report_template_ids = third_party_question
                                .question_group
                                .session
                                .report_templates
                                .third_party
                                .map { |report_template| report_template.id }
      third_party_question.body['data'].each do |element|
        element['report_template_ids'] = report_template_ids
      end
      third_party_question.save!
    end
  end

  def self.down; end
end

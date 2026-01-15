# frozen_string_literal: true

class Clone::Question < Clone::Base
  def execute
    generate_new_answer_ids
    clean_outcome_formulas if clean_formulas
    outcome.save!
    attach_answer_images
    attach_image
    assign_answer_images_to_correct_answers
    outcome
  end

  private

  def attach_image
    return unless source.image.attached?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(source.image.download),
      filename: source.image.filename,
      content_type: source.image.content_type
    )
    blob.update!(description: source.image_blob.description)
    outcome.image.attach(blob)
  end

  def generate_new_answer_ids
    return unless source.type.in?(%w[Question::Single Question::Multiple Question::ThirdParty Question::Grid])

    if source.type == 'Question::Grid'
      outcome.body.dig('data', 0, 'payload', 'rows').each do |row|
        row['id'] = SecureRandom.uuid
      end
      outcome.body.dig('data', 0, 'payload', 'columns').each do |row|
        row['id'] = SecureRandom.uuid
      end
    else
      outcome.body['data'].each do |answer|
        answer['id'] = SecureRandom.uuid
      end
    end
  end

  def attach_answer_images
    return if source.answer_images.empty?

    source.answer_images.each do |answer_image|
      source_answer_id = answer_image.metadata['answer_id']
      source_answer_index = source.body&.dig('data')&.find_index { |answer| answer['id'].eql?(source_answer_id) }
      next if source_answer_index.blank?

      outcome_answer_id = outcome.body&.dig('data')&.at(source_answer_index)&.dig('id')

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(answer_image.download),
        filename: answer_image.filename,
        content_type: answer_image.content_type,
        metadata: { answer_id: outcome_answer_id }
      )
      blob.update(description: answer_image.blob.description) if answer_image.blob.description.present?
      outcome.answer_images.attach(blob)
    end
  end

  def assign_answer_images_to_correct_answers
    return if outcome.answer_images.empty?

    outcome.answer_images.each do |answer_image|
      answer_id = answer_image.metadata['answer_id']
      answer_index = outcome.body&.dig('data')&.find_index { |answer| answer['id'].eql?(answer_id) }
      next if answer_index.nil?

      outcome.body['data'][answer_index]['image_id'] = answer_image.attachment_ids.first
    end
    outcome.save!
  end

  def clean_outcome_formulas
    @session_variables ||= outcome.question_group.session.session_variables.uniq
    outcome.variable_clone_prefix(@session_variables)
    outcome.formulas = Question.assign_default_values('formulas')
  end
end

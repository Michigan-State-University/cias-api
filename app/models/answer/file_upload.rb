# frozen_string_literal: true

class Answer::FileUpload < Answer
  CSV_SEPARATOR = "\n"
  PENDING_CELL = 'FILE PENDING SCAN'
  REMOVED_CELL = 'FILE REMOVED BY SECURITY SCAN'
  MISSING_CELL = 'FILE NO LONGER AVAILABLE'

  validate :uploads_belong_to_this_answer
  validate :uploads_referenced_once

  def self.preload_participant_uploads(answers)
    targets = answers.select { |answer| answer.is_a?(self) }
    return answers if targets.empty?

    by_id = ParticipantUpload.where(id: targets.flat_map(&:referenced_upload_ids).uniq).index_by(&:id)
    targets.each { |answer| answer.seed_participant_uploads(by_id) }
    answers
  end

  def seed_participant_uploads(by_id)
    @participant_uploads = referenced_upload_ids.filter_map { |id| by_id[id] }
  end

  def participant_uploads
    @participant_uploads ||= begin
      ids = referenced_upload_ids
      ids.empty? ? [] : ParticipantUpload.where(id: ids).in_order_of(:id, ids).to_a
    end
  end

  def referenced_upload_ids
    Array(body_data).flat_map { |data| Array(data['value']) }.compact_blank
  end

  def csv_header_name(_data)
    question.question_variables.first
  end

  def csv_row_value(data)
    Array(data['value']).map { |upload_id| csv_cell_for(uploads_by_id[upload_id]) }.join(CSV_SEPARATOR)
  end

  private

  def uploads_by_id
    @uploads_by_id ||= participant_uploads.index_by(&:id)
  end

  def uploads_belong_to_this_answer
    referenced = referenced_upload_ids
    return if referenced.empty?

    owned = ParticipantUpload.where(id: referenced, user_session_id: user_session_id, question_id: question_id).pluck(:id)
    return if (referenced - owned).empty?

    errors.add(:body, :foreign_upload_referenced)
  end

  def uploads_referenced_once
    referenced = referenced_upload_ids
    return if referenced.size == referenced.uniq.size

    errors.add(:body, :duplicated_upload_referenced)
  end

  def csv_cell_for(upload)
    return MISSING_CELL if upload.nil?
    return REMOVED_CELL if upload.removed_by_scanner?
    return PENDING_CELL unless upload.servable?

    "#{ENV.fetch('WEB_URL', nil)}/participant-uploads/#{upload.id}"
  end
end

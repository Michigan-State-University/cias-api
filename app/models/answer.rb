# frozen_string_literal: true

class Answer < ApplicationRecord
  has_paper_trail
  include BodyInterface

  belongs_to :question, inverse_of: :answers, optional: true
  belongs_to :user_session, optional: true

  attribute :decrypted_body, :json, default: -> { { data: [] } }
  attribute :body, :json, default: -> { { data: [] } }

  delegate :subclass_name, :settings, :position, :title, :subtitle, :formulas, to: :question, allow_nil: true

  validate :type_integrity_validator

  scope :confirmed, -> { where(draft: false) }
  scope :final, -> { where(alternative_branch: false) }
  scope :user_answers, lambda { |user_id, session_ids|
    relation = joins(:user_session).where(user_sessions: { user_id: user_id })
    relation = relation.where('user_sessions.session_id IN(?)', session_ids) if session_ids.any?
    relation
  }

  scope :hfhs, -> { where(type: Answer::HenryFord.name) }

  encrypts :body, type: :json, migrating: true

  default_scope { order(:created_at) }

  def on_answer; end

  def csv_header_name(data)
    data['var']
  end

  def csv_row_value(data)
    data['value']
  end

  def csv_row_video_stats
    "Video Started: #{video_stats['video_start'] || 'NOT STARTED'}\n"\
      "Video Ended: #{video_stats['video_end'] || 'NOT ENDED'}\n"\
      "Progress: #{(video_stats.dig(:video_progress, :played).to_f * 100).round}%"
  end

  def decrypted_body
    return { 'data' => [] } unless body_ciphertext

    Answer.decrypt_body_ciphertext(body_ciphertext)
  end

  private

  def type_integrity_validator
    return if type.demodulize.eql?(subclass_name) || type.eql?('Answer::CatMh')

    errors.add(:type, 'broken type integrity')
  end
end

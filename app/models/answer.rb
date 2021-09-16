# frozen_string_literal: true

class Answer < ApplicationRecord
  has_paper_trail
  include BodyInterface

  belongs_to :question, inverse_of: :answers, optional: true
  belongs_to :user_session, optional: true

  attribute :decrypted_body, :json, default: { data: [] }
  attribute :body, :json, default: { data: [] }

  delegate :subclass_name, :settings, :position, :title, :subtitle, :formula, to: :question, allow_nil: true

  validate :type_integrity_validator

  scope :user_answers, lambda { |user_id, session_ids|
    relation = joins(:user_session).where(user_sessions: { user_id: user_id })
    relation = relation.where('user_sessions.session_id IN(?)', session_ids) if session_ids.any?
    relation
  }

  encrypts :body, type: :json, migrating: true

  def on_answer; end

  def csv_header_name(data)
    data['var']
  end

  def csv_row_value(data)
    data['value']
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

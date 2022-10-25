# frozen_string_literal: true

class LiveChat::TranscriptMailer < ApplicationMailer
  def conversation_transcript(email, conversation)
    @email = email
    @intervention = conversation.intervention
    @conversation = conversation

    mail(to: email, subject: I18n.t('transcript_mailer.conversation_transcript_ready.subject'))
  end

  def intervention_transcript(email, intervention)
    @email = email
    @intervention = intervention

    mail(to: email, subject: I18n.t('transcript_mailer.intervention_conversation_transcripts_ready.subject'))
  end
end

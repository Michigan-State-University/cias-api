# frozen_string_literal: true

class V1::ParticipantUploads::AcceptAllAdapter
  def scan(_blob)
    :clean
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :live_chat_interlocutor, class: LiveChat::Interlocutor do
    association(:user)
    association(:conversation)
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :live_chat_message, class: LiveChat::Message do
    content { Faker::ProgrammingLanguage.name }
    association(:conversation)
    association(:live_chat_interlocutor)
  end
end

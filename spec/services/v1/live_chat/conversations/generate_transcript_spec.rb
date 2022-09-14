# frozen_string_literal: true

RSpec.describe V1::LiveChat::Conversations::GenerateTranscript do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: researcher) }
  let(:result) { service_class.call(target_record) }

  context 'Transcript for single conversation' do
    let(:service_class) { V1::LiveChat::Conversations::GenerateTranscript::Conversation }
    let(:conversation) { create(:live_chat_conversation, intervention: intervention) }
    let!(:navigator) do
      user = create(:user, :navigator, :confirmed)
      conversation.live_chat_interlocutors << LiveChat::Interlocutor.new(user: user)
      user
    end
    let(:target_record) { conversation }

    context 'Correctly generates data when participant is registered' do
      let!(:participant) do
        user = create(:user, :participant, :confirmed)
        conversation.live_chat_interlocutors << LiveChat::Interlocutor.new(user: user)
        user
      end
      let!(:messages) do
        conversation.messages << [
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: navigator.id), content: 'Hello there'),
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: participant.id), content: 'Hello?'),
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: navigator.id), content: 'Welcome')
        ]
      end
      let!(:expected) do
        [
          "\"Intervention: #{intervention.name}\"",
          "\"Navigator: #{navigator.full_name} <#{navigator.email}>\"",
          "\"Participant: #{participant.full_name} <#{participant.email}>\"",
          messages.map { |m| "#{m.user.navigator? ? 'N' : 'P'},#{m.created_at.strftime('%m-%d-%Y_%H%M')},\"#{m.content}\"" }
        ].flatten
      end

      it do
        expect(result.csv_content).to eq expected
      end
    end

    context 'Correctly generates data when participant isn\'t registered' do
      let(:guest) do
        user = create(:user, :guest, :confirmed)
        conversation.live_chat_interlocutors << LiveChat::Interlocutor.new(conversation: conversation, user: user)
        user
      end

      let!(:messages) do
        conversation.messages << [
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: navigator.id), content: 'Hello there'),
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: guest.id), content: 'Hello?'),
          LiveChat::Message.new(live_chat_interlocutor: conversation.live_chat_interlocutors.find_by(user_id: navigator.id), content: 'Welcome')
        ]
      end

      let!(:expected) do
        [
          "\"Intervention: #{intervention.name}\"",
          "\"Navigator: #{navigator.full_name} <#{navigator.email}>\"",
          "\"Participant: <#{guest.id}>\"",
          messages.map { |m| "#{m.user.navigator? ? 'N' : 'P'},#{m.created_at.strftime('%m-%d-%Y_%H%M')},\"#{m.content}\"" }
        ].flatten
      end

      it do
        expect(result.csv_content).to eq expected
      end
    end
  end

  context 'Transcript for entire intervention' do
    let(:service_class) { V1::LiveChat::Conversations::GenerateTranscript::Intervention }
    let(:target_record) { intervention }
    let(:navigator) { create(:user, :navigator, :confirmed) }
    let(:participants) { create_list(:user, 3, :confirmed, :participant) }
    let!(:conversations) do
      participants.map do |participant|
        navigator_interlocutor = LiveChat::Interlocutor.new(user: navigator)
        participant_interlocutor = LiveChat::Interlocutor.new(user: participant)
        conversation = LiveChat::Conversation.create!(live_chat_interlocutors: [navigator_interlocutor, participant_interlocutor], intervention: intervention)
        conversation.messages << [
          LiveChat::Message.new(content: 'Hey hey people', live_chat_interlocutor: navigator_interlocutor),
          LiveChat::Message.new(content: 'HTD here', live_chat_interlocutor: participant_interlocutor),
          LiveChat::Message.new(content: 'Bringing the best software there is', live_chat_interlocutor: navigator_interlocutor)
        ]
        conversation
      end
    end

    let(:expected) do
      conversations.map do |conv|
        navigator = conv.users.limit_to_roles('navigator').first
        participant = conv.users.limit_to_roles(%w[guest participant]).first
        [
          "\"Intervention: #{conv.intervention.name}\"",
          "\"Navigator: #{navigator.full_name} <#{navigator.email}>\"",
          "\"Participant: #{participant.guest? ? "<#{participant.id}>" : "#{participant.full_name} <#{participant.email}>"}\"",
          conv.messages.map { |m| "#{m.user.navigator? ? 'N' : 'P'},#{m.created_at.strftime('%m-%d-%Y_%H%M')},\"#{m.content}\"" }
        ]
      end.flatten
    end

    it do
      expect(result.csv_content).to eq expected
    end
  end
end

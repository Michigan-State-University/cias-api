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
          ['Intervention name', 'Location history', 'Participant ID', 'Date EST', 'Inititation time EST', 'Duration', 'Message 1', 'Message 2', 'Message 3'],
          [intervention.name, conversation.participant_location_history, participant.id,
           conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%m/%d/%Y'),
           conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%I:%M:%S %p'),
           nil, '[N] "Hello there"', '[P] "Hello?"', '[N] "Welcome"']
        ]
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
          ['Intervention name', 'Location history', 'Participant ID', 'Date EST', 'Inititation time EST', 'Duration', 'Message 1', 'Message 2', 'Message 3'],
          [intervention.name, conversation.participant_location_history, guest.id,
           conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%m/%d/%Y'),
           conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%I:%M:%S %p'), nil,
           *conversation.messages.map { |message| "[#{message.user.navigator? ? 'N' : 'P'}] \"#{message.content}\"" }]
        ]
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
          LiveChat::Message.new(live_chat_interlocutor: navigator_interlocutor, content: 'Hey hey people'),
          LiveChat::Message.new(live_chat_interlocutor: participant_interlocutor, content: 'HTD here'),
          LiveChat::Message.new(live_chat_interlocutor: navigator_interlocutor, content: 'Bringing the best software there is')
        ]
        conversation
      end
    end

    let(:expected) do
      [
        ['Intervention name', 'Location history', 'Participant ID', 'Date EST', 'Inititation time EST', 'Duration', 'Message 1', 'Message 2', 'Message 3'],
        *conversations.zip(participants).map do |(conversation, participant)|
          [
            intervention.name, conversation.participant_location_history, participant.id,
            conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%m/%d/%Y'),
            conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%I:%M:%S %p'), nil,
            *conversation.messages.map { |message| "[#{message.user.navigator? ? 'N' : 'P'}] \"#{message.content}\"" }
          ]
        end
      ]
    end

    it do
      expect(result.csv_content).to eq expected
    end

    context 'when multiple conversations dont have the same amount of messages' do
      let!(:conversations) do
        participants.map do |participant|
          message_contents = ['Hey hey people', 'HTD here', 'Bringing the best software there is']
          navigator_interlocutor = LiveChat::Interlocutor.new(user: navigator)
          participant_interlocutor = LiveChat::Interlocutor.new(user: participant)
          interlocutors = [navigator_interlocutor, participant_interlocutor]
          conversation = LiveChat::Conversation.create!(live_chat_interlocutors: [navigator_interlocutor, participant_interlocutor], intervention: intervention)
          conversation.messages << 3.times.map do # rubocop:disable Performance/TimesMap
            LiveChat::Message.new(live_chat_interlocutor: interlocutors.sample, content: message_contents.sample)
          end
          conversation
        end
      end

      let(:expected) do
        message_count = conversations.map { |c| c.messages.size }.max
        [
          ['Intervention name', 'Location history', 'Participant ID', 'Date EST', 'Inititation time EST', 'Duration',
           *(0...message_count).map { |i| "Message #{i + 1}" }],
          *conversations.map do |conversation|
            array = [intervention.name, conversation.participant_location_history, conversation.other_user.id,
                     conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%m/%d/%Y'),
                     conversation.created_at.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')).strftime('%I:%M:%S %p'), nil,
                     *conversation.messages.map { |message| "[#{message.user.navigator? ? 'N' : 'P'}] \"#{message.content}\"" }]
            array << ([nil] * (message_count - conversation.messages.size)) if array.size < message_count
            array
          end
        ]
      end

      it do
        expect(result.csv_content).to eq expected
      end
    end
  end
end

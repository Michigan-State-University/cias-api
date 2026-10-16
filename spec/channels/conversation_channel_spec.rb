# frozen_string_literal: true

RSpec.describe ConversationChannel, type: :channel do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:navigator) { create(:user, :confirmed, :navigator, online: true) }
  let(:intervention) { create(:intervention, :with_navigator_setup) }
  let(:current_user) { participant }
  let(:conversation) do
    LiveChat::Conversation.create!(
      intervention: intervention,
      live_chat_interlocutors: [LiveChat::Interlocutor.new(user: navigator), LiveChat::Interlocutor.new(user: participant)]
    )
  end
  let(:participant_interlocutor) { conversation.live_chat_interlocutors.find_by(user: participant) }
  let(:participant_channel) { "user_conversation_channel_#{participant.id}" }
  let(:navigator_channel) { "user_conversation_channel_#{navigator.id}" }
  let(:navigators_channel) { "navigators_in_intervention_channel_#{intervention.id}" }

  before do
    intervention.navigators << navigator
    allow(V1::LiveChat::Interventions::Navigators::SendMessages).to receive(:call)
    stub_connection(current_user: current_user)
  end

  describe '#subscribed' do
    context 'without intervention_id' do
      before { subscribe }

      it 'streams only from the current user channel' do
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(participant_channel)
        expect(subscription).not_to have_stream_from(navigators_channel)
      end
    end

    context 'with intervention_id and an online navigator' do
      it 'streams from the user and intervention navigators channels' do
        subscribe intervention_id: intervention.id

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(participant_channel)
        expect(subscription).to have_stream_from(navigators_channel)
      end

      it 'does not report navigator unavailability' do
        expect { subscribe intervention_id: intervention.id }.not_to have_broadcasted_to(participant_channel)
      end
    end

    context 'with intervention_id and no online navigator' do
      let(:navigator) { create(:user, :confirmed, :navigator, online: false) }

      it 'reports navigator unavailability to the current user' do
        expect { subscribe intervention_id: intervention.id }
          .to have_broadcasted_to(participant_channel).with({ data: {}, topic: 'navigator_unavailable', status: 404 })
      end

      it 'still streams from the intervention navigators channel' do
        subscribe intervention_id: intervention.id

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(navigators_channel)
      end
    end
  end

  describe '#unsubscribed' do
    it 'stops all streams' do
      subscribe intervention_id: intervention.id
      unsubscribe

      expect(subscription).not_to have_streams
    end
  end

  describe '#on_message_sent' do
    before { subscribe }

    let(:send_message) do
      perform :on_message_sent, conversationId: conversation.id, interlocutorId: participant_interlocutor.id, content: content
    end
    let(:content) { 'Hello navigator' }

    it 'creates the message' do
      expect { send_message }.to change(LiveChat::Message, :count).by(1)
      expect(LiveChat::Message.reorder(:created_at).last)
        .to have_attributes(content: content, conversation: conversation, live_chat_interlocutor: participant_interlocutor)
    end

    it 'broadcasts the message to every interlocutor' do
      expect { send_message }
        .to have_broadcasted_to(participant_channel).with { |msg| expect(msg).to include('topic' => 'message_sent', 'status' => 200) }
        .and have_broadcasted_to(navigator_channel).with { |msg| expect(msg).to include('topic' => 'message_sent', 'status' => 200) }
    end

    context 'when the content is too long' do
      let(:content) { 'a' * 501 }

      it 'does not create the message' do
        expect { send_message }.not_to change(LiveChat::Message, :count)
      end

      it 'broadcasts a message error to the current user only' do
        expect { send_message }
          .to have_broadcasted_to(participant_channel)
          .with { |msg| expect(msg).to include('topic' => 'message_error', 'status' => 422, 'data' => hash_including('conversationId' => conversation.id)) }
        expect { send_message }.not_to have_broadcasted_to(navigator_channel)
      end
    end

    context 'when the conversation is archived' do
      before { conversation.update!(archived_at: DateTime.now) }

      it 'does not create the message' do
        expect { send_message }.not_to change(LiveChat::Message, :count)
      end

      it 'broadcasts a message error to the current user' do
        expect { send_message }
          .to have_broadcasted_to(participant_channel).with { |msg| expect(msg).to include('topic' => 'message_error', 'status' => 422) }
      end
    end
  end

  describe '#on_message_read' do
    let(:message) { LiveChat::Message.create!(conversation: conversation, content: 'Hi', live_chat_interlocutor: participant_interlocutor) }
    let(:expected_response) { { data: { messageId: message.id, conversationId: conversation.id }, topic: 'message_read', status: 200 } }

    before { subscribe }

    it 'marks the message as read' do
      perform :on_message_read, messageId: message.id

      expect(message.reload.is_read).to be(true)
    end

    it 'broadcasts the read receipt to every interlocutor' do
      expect { perform :on_message_read, messageId: message.id }
        .to have_broadcasted_to(participant_channel).with(expected_response)
        .and have_broadcasted_to(navigator_channel).with(expected_response)
    end
  end

  describe '#on_current_screen_title_changed' do
    let(:change_screen) do
      perform :on_current_screen_title_changed, conversationId: conversation.id, currentScreenTitle: 'Question 2', currentLocation: '/sessions/2'
    end

    before { subscribe }

    it 'stores the title and the location' do
      change_screen

      expect(conversation.reload).to have_attributes(current_screen_title: 'Question 2', participant_location_history: ['/sessions/2'])
    end

    it 'does not duplicate the last location' do
      change_screen
      change_screen

      expect(conversation.reload.participant_location_history).to eq(['/sessions/2'])
    end

    it 'broadcasts the new title to the navigator' do
      expect { change_screen }
        .to have_broadcasted_to(navigator_channel)
        .with({ data: { currentScreenTitle: 'Question 2', conversationId: conversation.id }, topic: 'current_screen_title_changed', status: 200 })
    end
  end

  describe '#on_conversation_created' do
    let(:create_conversation) do
      perform :on_conversation_created, interventionId: intervention.id, firstMessageContent: 'I need help'
    end
    let(:created_conversation) { LiveChat::Conversation.order(:created_at).last }

    before { subscribe }

    it 'creates a conversation between the participant and the navigator with the first message' do
      expect { create_conversation }.to change(LiveChat::Conversation, :count).by(1)
      expect(created_conversation.users).to contain_exactly(participant, navigator)
      expect(created_conversation.messages.map(&:content)).to eq(['I need help'])
      expect(created_conversation.messages.first.user).to eq(participant)
    end

    it 'broadcasts the conversation to the participant and the navigator' do
      expect { create_conversation }
        .to have_broadcasted_to(participant_channel).with { |msg| expect(msg).to include('topic' => 'conversation_created', 'status' => 200) }
        .and have_broadcasted_to(navigator_channel).with { |msg| expect(msg).to include('topic' => 'conversation_created', 'status' => 200) }
    end

    context 'when several navigators are online' do
      let(:busy_navigator) { navigator }
      let!(:free_navigator) { create(:user, :confirmed, :navigator, online: true) }

      before do
        intervention.navigators << free_navigator
        conversation
      end

      it 'assigns the navigator with the fewest active conversations' do
        create_conversation

        expect(created_conversation.users).to contain_exactly(participant, free_navigator)
      end
    end

    context 'when no navigator is online' do
      let(:navigator) { create(:user, :confirmed, :navigator, online: false) }

      it 'does not create a conversation' do
        expect { create_conversation }.not_to change(LiveChat::Conversation, :count)
      end

      it 'broadcasts a navigator unavailable error to the current user' do
        expect { create_conversation }
          .to have_broadcasted_to(participant_channel).with { |msg| expect(msg).to include('topic' => 'navigator_unavailable_error', 'status' => 404) }
      end
    end

    context 'when the participant called out navigators before' do
      let!(:summoning_user) { LiveChat::SummoningUser.create!(user: participant, intervention: intervention, participant_handled: false) }

      it 'notifies the other navigators that the participant is handled' do
        create_conversation

        expect(V1::LiveChat::Interventions::Navigators::SendMessages).to have_received(:call).with(intervention, 'cancel_call_out', navigator)
        expect(summoning_user.reload.participant_handled).to be(true)
      end
    end
  end

  describe '#on_conversation_archived' do
    let(:current_user) { navigator }

    before { subscribe }

    it 'archives the conversation' do
      perform :on_conversation_archived, conversationId: conversation.id

      expect(conversation.reload.archived_at).to be_present
    end

    it 'broadcasts the archivization to every conversation user' do
      expect { perform :on_conversation_archived, conversationId: conversation.id }
        .to have_broadcasted_to(participant_channel).with { |msg| expect(msg).to include('topic' => 'conversation_archived', 'status' => 200) }
        .and have_broadcasted_to(navigator_channel).with { |msg| expect(msg).to include('topic' => 'conversation_archived', 'status' => 200) }
    end
  end

  describe '#on_fetch_live_chat_setup' do
    before { subscribe }

    it 'broadcasts the intervention live chat setup to the current user' do
      expect { perform :on_fetch_live_chat_setup, interventionId: intervention.id }
        .to have_broadcasted_to(participant_channel).with { |msg|
          expect(msg).to include('topic' => 'live_chat_setup_fetched', 'status' => 200)
          expect(msg.dig('data', 'data', 'id')).to eq(intervention.navigator_setup.id)
        }
    end
  end

  describe '#on_call_out_navigator' do
    let(:call_out) { perform :on_call_out_navigator, interventionId: intervention.id }

    before { subscribe }

    it 'registers the participant as waiting for a navigator' do
      expect { call_out }.to change(LiveChat::SummoningUser, :count).by(1)
      expect(LiveChat::SummoningUser.order(:created_at).last)
        .to have_attributes(user_id: participant.id, intervention_id: intervention.id, participant_handled: false)
    end

    it 'calls out the navigators' do
      call_out

      expect(V1::LiveChat::Interventions::Navigators::SendMessages).to have_received(:call).with(intervention, 'call_out')
    end

    it 'confirms the call out to the current user' do
      expect { call_out }.to have_broadcasted_to(participant_channel).with({ data: { unlockTime: nil }, topic: 'navigators_called_out', status: 200 })
    end

    context 'when the participant has already called out' do
      let!(:summoning_user) { LiveChat::SummoningUser.create!(user: participant, intervention: intervention, participant_handled: true) }

      it 'reuses the existing record' do
        expect { call_out }.not_to change(LiveChat::SummoningUser, :count)
        expect(summoning_user.reload.participant_handled).to be(false)
      end
    end
  end

  describe '#on_cancel_call_out' do
    let(:cancel_call_out) { perform :on_cancel_call_out, interventionId: intervention.id }

    before { subscribe }

    context 'when the participant is waiting for a navigator' do
      let!(:summoning_user) { LiveChat::SummoningUser.create!(user: participant, intervention: intervention, participant_handled: false) }

      it 'notifies the navigators and marks the participant as handled' do
        cancel_call_out

        expect(V1::LiveChat::Interventions::Navigators::SendMessages).to have_received(:call).with(intervention, 'cancel_call_out', nil)
        expect(summoning_user.reload.participant_handled).to be(true)
      end

      it 'confirms the cancellation to the current user' do
        expect { cancel_call_out }
          .to have_broadcasted_to(participant_channel).with({ data: { summoningUserId: summoning_user.id }, topic: 'call_out_canceled', status: 200 })
      end
    end

    context 'when the participant did not call out' do
      it 'does not notify the navigators' do
        cancel_call_out

        expect(V1::LiveChat::Interventions::Navigators::SendMessages).not_to have_received(:call)
      end

      it 'confirms the cancellation without a summoning user' do
        expect { cancel_call_out }
          .to have_broadcasted_to(participant_channel).with({ data: { summoningUserId: nil }, topic: 'call_out_canceled', status: 200 })
      end
    end
  end
end

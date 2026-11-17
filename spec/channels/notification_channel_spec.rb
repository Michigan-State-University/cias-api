# frozen_string_literal: true

RSpec.describe NotificationChannel, type: :channel do
  let(:current_user) { create(:user, :confirmed, :participant, online: false) }
  let(:user_channel) { "notification_channel_#{current_user.id}" }

  before { stub_connection(current_user: current_user) }

  describe '#subscribed' do
    it 'streams from the current user notification channel' do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from(user_channel)
    end

    it 'marks the user as online' do
      subscribe

      expect(current_user.reload.online).to be(true)
    end

    context 'with notifications' do
      let(:intervention) { create(:intervention) }
      let!(:unread_notification) do
        Notification.create!(user: current_user, notifiable: intervention, event: :start_editing_intervention, data: { intervention_id: intervention.id })
      end

      before do
        Notification.create!(user: current_user, notifiable: intervention, event: :stop_editing_intervention,
                             data: { intervention_id: intervention.id }, is_read: true)
        Notification.create!(user: create(:user, :confirmed), notifiable: intervention, event: :start_editing_intervention,
                             data: { intervention_id: intervention.id })
      end

      it 'sends only the unread notifications of the current user' do
        expect { subscribe }
          .to have_broadcasted_to(user_channel).with { |msg|
            expect(msg).to include('topic' => 'unread_notifications_fetched', 'status' => 200)
            expect(msg.dig('data', 'data').pluck('id')).to eq([unread_notification.id])
          }
      end
    end

    context 'when the user is a navigator and a researcher' do
      let(:current_user) { create(:user, :confirmed, :researcher_and_navigator, online: false) }

      it 'does not change the online status' do
        subscribe

        expect(current_user.reload.online).to be(false)
      end
    end
  end

  describe '#on_read_notification' do
    let(:notification) do
      Notification.create!(user: current_user, notifiable: create(:intervention), event: :start_editing_intervention, data: {})
    end

    it 'marks the notification as read' do
      subscribe
      perform :on_read_notification, notificationId: notification.id

      expect(notification.reload.is_read).to be(true)
    end
  end

  context 'when the user is a navigator' do
    let(:current_user) { create(:user, :confirmed, :navigator, online: false) }
    let(:participant) { create(:user, :confirmed, :participant) }
    let(:intervention) { create(:intervention, :with_navigator_setup) }
    let(:other_intervention) { create(:intervention, :with_navigator_setup) }
    let(:navigators_channel) { "navigators_in_intervention_channel_#{intervention.id}" }
    let(:participant_conversation_channel) { "user_conversation_channel_#{participant.id}" }
    let(:redis_url) { ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
    let(:redis_connection) { Redis.new(url: redis_url) }
    let(:subscriber) { Redis.new(url: redis_url) }
    let!(:conversation) do
      LiveChat::Conversation.create!(
        intervention: intervention,
        live_chat_interlocutors: [LiveChat::Interlocutor.new(user: current_user), LiveChat::Interlocutor.new(user: participant)]
      )
    end

    # The test cable adapter has no Redis, so the channel gets a real Redis client and a real
    # subscription (with the production channel prefix) for a participant waiting in `intervention`.
    before do
      intervention.navigators << current_user
      other_intervention.navigators << current_user
      connection = redis_connection
      ActionCable.server.pubsub.define_singleton_method(:redis_connection) { connection }

      subscribed = Queue.new
      @subscription_listener = Thread.new do # rubocop:disable ThreadSafety/NewThread
        subscriber.subscribe("cias-api_test#{navigators_channel}") { |on| on.subscribe { subscribed << true } }
      end
      raise 'Redis subscription was not established' unless subscribed.pop(timeout: 5)
    end

    after do
      @subscription_listener.kill
      subscriber.close
      redis_connection.close
    end

    describe '#subscribed' do
      it 'marks the navigator as online' do
        subscribe

        expect(current_user.reload.online).to be(true)
      end

      it 'tells participants waiting in the intervention that a navigator is available' do
        expect { subscribe }
          .to have_broadcasted_to(navigators_channel).with({ interventionId: intervention.id, topic: 'navigator_available', status: 200 })
      end

      it 'tells the conversation partner that the navigator is available' do
        expect { subscribe }
          .to have_broadcasted_to(participant_conversation_channel)
          .with({ data: { interventionId: intervention.id, conversationId: conversation.id }, topic: 'current_navigator_available', status: 200 })
      end

      it 'skips interventions without active subscribers' do
        expect { subscribe }.not_to have_broadcasted_to("navigators_in_intervention_channel_#{other_intervention.id}")
      end
    end

    describe '#unsubscribed' do
      before { subscribe }

      it 'stops all streams and marks the navigator as offline' do
        unsubscribe

        expect(subscription).not_to have_streams
        expect(current_user.reload.online).to be(false)
      end

      it 'tells participants waiting in the intervention that no navigator is available' do
        expect { unsubscribe }
          .to have_broadcasted_to(navigators_channel).with({ interventionId: intervention.id, topic: 'navigator_unavailable', status: 404 })
      end

      it 'tells the conversation partner that the navigator is unavailable' do
        expect { unsubscribe }
          .to have_broadcasted_to(participant_conversation_channel)
          .with({ data: { interventionId: intervention.id, conversationId: conversation.id }, topic: 'current_navigator_unavailable', status: 404 })
      end

      context 'when another navigator is still online' do
        before { intervention.navigators << create(:user, :confirmed, :navigator, online: true) }

        it 'keeps the intervention available' do
          expect { unsubscribe }
            .to have_broadcasted_to(navigators_channel).with({ interventionId: intervention.id, topic: 'navigator_available', status: 200 })
        end
      end
    end

    describe '#on_navigator_availability_set' do
      before { subscribe }

      it 'updates the online status' do
        perform :on_navigator_availability_set, online: false

        expect(current_user.reload.online).to be(false)
      end

      it 'broadcasts the new availability' do
        expect { perform :on_navigator_availability_set, online: false }
          .to have_broadcasted_to(navigators_channel).with({ interventionId: intervention.id, topic: 'navigator_unavailable', status: 404 })
      end
    end
  end
end

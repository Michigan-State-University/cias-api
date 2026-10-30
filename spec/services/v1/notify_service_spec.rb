# frozen_string_literal: true

RSpec.describe V1::NotifyService do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let(:notification) do
    Notification.new(user: user, notifiable: intervention, event: :start_editing_intervention, data: { intervention_id: intervention.id })
  end

  it 'broadcasts a new notification to the user notification channel when it is created' do
    expect { notification.save! }
      .to have_broadcasted_to("notification_channel_#{user.id}").with { |msg|
        expect(msg).to include('topic' => 'new_notification', 'status' => 200)
        expect(msg.dig('data', 'data', 'id')).to eq(notification.id)
      }
  end

  it 'does not broadcast to other users' do
    other_user = create(:user, :confirmed)

    expect { notification.save! }.not_to have_broadcasted_to("notification_channel_#{other_user.id}")
  end
end

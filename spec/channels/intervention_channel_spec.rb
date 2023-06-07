# frozen_string_literal: true

RSpec.describe InterventionChannel, type: :channel do
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_collaborators, user: researcher) }

  before do
    stub_connection({ current_user: current_user, id: intervention.id })
    subscribe id: intervention.id
  end

  context 'intervention owner' do
    let(:current_user) { researcher }

    context 'subscribe' do
      it 'successfully subscribes' do
        expect(subscription).to(be_confirmed)
      end

      it 'successfully stream from' do
        expect(subscription).to(have_stream_from("intervention_channel_#{intervention.id}"))
      end
    end

    context 'handle message from clinet -> #start_editing' do
      it 'update current editor' do
        perform :on_editing_started, interventionId: intervention.id
        expect(intervention.reload.current_editor_id).to eql(current_user.id)
      end

      it 'create notifications' do
        expect do
          perform :on_editing_started, interventionId: intervention.id
        end.to change(Notification, :count).by(1)
      end

      it 'brodcast message' do
        expect { perform :on_editing_started, interventionId: intervention.id }
          .to have_broadcasted_to("intervention_channel_#{intervention.id}")
                .with({
                        data: { current_editor: { id: current_user.id, email: current_user.email, first_name: current_user.first_name,
                                                  last_name: current_user.last_name } }, topic: 'editing_started', status: 200
                      })
      end

      context 'when sb editing the intervention' do
        it 'reject action' do
          intervention.update(current_editor_id: intervention.collaborators.first.user_id)

          perform :on_editing_started, interventionId: intervention.id
          expect(subscription).to(be_rejected)
        end
      end
    end

    context 'handle message from client -> #stop_editing' do
      before do
        intervention.update(current_editor_id: current_user.id)
      end

      it 'update current editor' do
        subscribe id: intervention.id
        perform :on_editing_stopped, interventionId: intervention.id
        expect(intervention.reload.current_editor_id).to be_nil
      end

      it 'create notifications' do
        subscribe id: intervention.id
        expect do
          perform :on_editing_stopped, interventionId: intervention.id
        end.to change(Notification, :count).by(1)
      end

      it 'brodcast message' do
        subscribe id: intervention.id
        expect { perform :on_editing_stopped, interventionId: intervention.id }
          .to have_broadcasted_to("intervention_channel_#{intervention.id}")
                .with({ data: {}, topic: 'editing_stopped', status: 200 })
      end

      context 'when sb editing the intervention' do
        it 'reject action' do
          intervention.update(current_editor_id: intervention.collaborators.first.user_id)

          subscribe id: intervention.id
          perform :on_editing_stopped, interventionId: intervention.id
          expect(subscription).to(be_rejected)
        end
      end
    end

    context 'handle message from client -> #force_editing' do
      let(:researcher) { create(:user, :researcher, :confirmed) }

      before do
        intervention.update(current_editor: researcher)
      end

      it 'update current editor' do
        perform :on_force_editing_started, interventionId: intervention.id
        expect(intervention.reload.current_editor_id).to eql(current_user.id)
      end

      it 'brodcast message' do
        expect { perform :on_force_editing_started, interventionId: intervention.id }
          .to have_broadcasted_to("intervention_channel_#{intervention.id}")
                .with({ data: { current_editor: { id: current_user.id, email: current_user.email, first_name: current_user.first_name,
                                                  last_name: current_user.last_name }, topic: 'force_editing_started', status: 200 } })
      end

      context 'when current user isn\'t the owner' do
        let(:current_user) { intervention.collaborators.first.user }

        it 'reject action' do
          intervention.update(current_editor_id: intervention.collaborators.first.user_id)

          perform :on_force_editing_started, interventionId: intervention.id
          expect(subscription).to(be_rejected)
        end

        it 'return correct message' do
          expect { perform :on_force_editing_started, interventionId: intervention.id }
            .to have_broadcasted_to("intervention_channel_#{intervention.id}")
                  .with({
                          data: { error: I18n.t('channels.collaboration.intervention.forbidden_action') }, topic: 'unexpected_error', status: 400
                        })
        end
      end
    end

    context 'unsubscribe' do
      it 'successfully unsubscribes' do
        expect(subscription).to be_confirmed

        # that's the way to perform an `unsubscribe` command
        subscription.unsubscribe_from_channel
      end

      context 'when user was current editor' do
        before do
          intervention.update(current_editor_id: current_user.id)
        end

        it 'create notifications' do
          expect(subscription).to be_confirmed

          expect do
            subscription.unsubscribe_from_channel
          end.to change(Notification, :count).by(1)
        end
      end
    end
  end

  context 'when user has not access for specific intervention' do
    let(:current_user) { create(:user) }

    it 'reject subscribes' do
      expect(subscription).to(be_rejected)
    end
  end
end

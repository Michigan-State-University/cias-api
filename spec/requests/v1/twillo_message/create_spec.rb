# frozen_string_literal: true

RSpec.describe 'POST /v1/sms/replay', type: :request do
  context 'when valid params are passed' do
    before do
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(
        {
          status: 200
        }
      )
    end

    let(:params) do
      {
        body: 'EXAMPLE',
        from: '+48555777555',
        to: '+48555777888'
      }
    end
    let(:request) { post v1_sms_replay_path, params: params }

    context 'basic functionality' do
      it 'receive and pass params to service' do
        expect(V1::Sms::Replay).to receive(:call).with(
          params[:from], params[:to], params[:body]
        )
        request
      end

      it 'correct type of response' do
        request
        expect(response.headers['Content-Type']).to eq('application/xml; charset=utf-8')
      end
    end

    context 'when sms_code is provided' do
      let(:params) do
        {
          body: 'SMS_CODE_1',
          from: user.phone.full_number,
          to: '+48555777888'
        }
      end

      context 'when user session with sms code is NOT created' do
        let!(:intervention) { create(:intervention) }
        let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention) }
        let(:user) { create(:user, :with_phone) }

        it 'creates new user session' do
          expect { request }.to change(user.user_sessions, :count).by(1)
        end
      end

      context 'when user session with sms code is already created' do
        let!(:intervention) { create(:intervention) }
        let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention) }
        let(:user) { create(:user, :with_phone) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session) }

        it 'does not create new user session' do
          expect { request }.not_to change(user.user_sessions, :count)
        end

        context 'and there is pending question' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:question) { create(:question_sms, question_group: question_group) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }

          it 'does not create new answer' do
            expect { request }.not_to change(user_session.answers, :count)
          end
        end

        context 'and there are no pending questions' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:question) { create(:question_sms, question_group: question_group) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }
          let!(:answer) { create(:answer_sms, user_session: user_session, question: question) }

          it 'does not create any answer' do
            expect { request }.not_to change(user_session.answers, :count)
          end
        end
      end
    end

    context 'when answer is provided' do
      let(:params) do
        {
          body: '1',
          from: user.phone.full_number,
          to: '+48555777888'
        }
      end

      context 'when there is pending question' do
        let!(:user) { create(:user, :with_phone) }
        let!(:intervention) { create(:intervention) }
        let!(:question_group_initial) { build(:question_group_initial) }
        let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
        let!(:question_group) { create(:sms_question_group, session: session) }
        let!(:question) { create(:question_sms, question_group: question_group) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session, current_question_id: question.id) }

        it 'creates new answer' do
          expect { request }.to change(user_session.answers, :count).by(1)
        end
      end

      context 'when there are no pending questions' do
        let!(:user) { create(:user, :with_phone) }
        let!(:intervention) { create(:intervention) }
        let!(:question_group_initial) { build(:question_group_initial) }
        let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
        let!(:question_group) { create(:sms_question_group, session: session) }
        let!(:question) { create(:question_sms, question_group: question_group) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session) }
        let!(:answer) { create(:answer_sms, user_session: user_session, question: question) }

        it 'does not create any answer' do
          expect { request }.not_to change(user_session.answers, :count)
        end
      end

      context 'when user session is not created' do
        let!(:intervention) { create(:intervention) }
        let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention) }
        let(:user) { create(:user, :with_phone) }

        it 'does not create any user session' do
          expect { request }.not_to change(user.user_sessions, :count)
        end
      end
    end
  end
end

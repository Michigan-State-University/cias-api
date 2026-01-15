# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsHelper do
  let(:dummy_class) do
    Class.new do
      include SmsHelper

      attr_accessor :user_session

      def initialize(user_session)
        @user_session = user_session
      end
    end
  end

  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user) { create(:user, :confirmed) }
  let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }
  let(:user_intervention) { create(:user_intervention, intervention: intervention, user: user) }
  let(:user_session) { create(:user_session, session: session, user: user, user_intervention: user_intervention) }
  let(:helper) { dummy_class.new(user_session) }

  describe '#random_time' do
    context 'when sms_send_time_type is specific_time' do
      let(:sms_plan) do
        create(:sms_plan,
               session: session,
               sms_send_time_type: 'specific_time',
               sms_send_time_details: { time: '14:30' })
      end

      it 'returns the specific time from plan details' do
        result = helper.random_time(sms_plan)

        expect(result[:hour]).to eq(14)
        expect(result[:min]).to eq(30)
      end

      context 'with different time' do
        let(:sms_plan) do
          create(:sms_plan,
                 session: session,
                 sms_send_time_type: 'specific_time',
                 sms_send_time_details: { time: '08:15' })
        end

        it 'returns the correct specific time' do
          result = helper.random_time(sms_plan)

          expect(result[:hour]).to eq(8)
          expect(result[:min]).to eq(15)
        end
      end
    end

    context 'when sms_send_time_type is time_range' do
      let(:sms_plan) do
        create(:sms_plan,
               session: session,
               sms_send_time_type: 'time_range',
               sms_send_time_details: { 'from' => '9', 'to' => '13' })
      end

      it 'returns a random time within the specified range' do
        result = helper.random_time(sms_plan)

        expect(result[:hour]).to be >= 9
        expect(result[:hour]).to be <= 13
        expect(result[:min]).to be >= 0
        expect(result[:min]).to be < 60
      end

      it 'generates time within the range across multiple calls' do
        results = Array.new(10) { helper.random_time(sms_plan) }

        # All results should be within the range
        results.each do |result|
          total_minutes = (result[:hour] * 60) + result[:min]
          expect(total_minutes).to be >= (9 * 60)
          expect(total_minutes).to be < (13 * 60)
        end
      end
    end

    context 'when sms_send_time_type is preferred_by_participant' do
      let(:sms_plan) do
        create(:sms_plan,
               session: session,
               sms_send_time_type: 'preferred_by_participant')
      end

      context 'when user has defined time ranges' do
        let!(:phone_answer) do
          create(:answer_phone, user_session: user_session,
                                body: {
                                  'data' => [
                                    {
                                      'var' => 'phone',
                                      'value' => {
                                        'iso' => 'US',
                                        'number' => '202-555-0173',
                                        'prefix' => '+1',
                                        'confirmed' => true,
                                        'time_ranges' => [{ 'from' => '10', 'to' => '15' }]
                                      }
                                    }
                                  ]
                                })
        end

        it 'returns a random time from user defined ranges' do
          result = helper.random_time(sms_plan)

          total_minutes = (result[:hour] * 60) + result[:min]
          expect(total_minutes).to be >= (10 * 60)
          expect(total_minutes).to be < (15 * 60)
        end
      end

      context 'when user has multiple time ranges' do
        let!(:phone_answer) do
          create(:answer_phone, user_session: user_session,
                                body: {
                                  'data' => [
                                    {
                                      'var' => 'phone',
                                      'value' => {
                                        'iso' => 'US',
                                        'number' => '202-555-0173',
                                        'prefix' => '+1',
                                        'confirmed' => true,
                                        'time_ranges' => [
                                          { 'from' => '9', 'to' => '11' },
                                          { 'from' => '14', 'to' => '16' }
                                        ]
                                      }
                                    }
                                  ]
                                })
        end

        it 'selects from one of the user defined ranges' do
          results = Array.new(20) { helper.random_time(sms_plan) }

          # At least one result should be in each range over multiple calls
          results.each do |result|
            total_minutes = (result[:hour] * 60) + result[:min]
            # Should be in either first range (9-11) or second range (14-16)
            in_first_range = total_minutes >= (9 * 60) && total_minutes < (11 * 60)
            in_second_range = total_minutes >= (14 * 60) && total_minutes < (16 * 60)

            expect(in_first_range || in_second_range).to be true
          end
        end
      end
    end
  end
end

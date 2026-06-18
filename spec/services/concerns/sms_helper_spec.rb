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

  describe '#timezone' do
    context 'when the participant has explicitly set a valid timezone in their phone answer' do
      let!(:phone_answer) do
        create(:answer_phone, user_session: user_session,
                              body: { 'data' => [{ 'var' => 'phone',
                                                   'value' => { 'iso' => 'US', 'number' => '202-555-0173', 'prefix' => '+1', 'confirmed' => true,
                                                                'timezone' => 'America/Bogota' } }] })
      end

      it 'returns the participant-provided timezone' do
        expect(helper.timezone).to eq('America/Bogota')
      end
    end

    context 'when the participant did not provide a timezone (no phone answer)' do
      it 'falls back to the timezone derived from the phone number' do
        # phone is +1 202-555-0173 → US → America/New_York via Phonelib
        expect(helper.timezone).to eq('America/New_York')
      end
    end

    context 'when the participant supplied an invalid timezone string' do
      let!(:phone_answer) do
        create(:answer_phone, user_session: user_session,
                              body: { 'data' => [{ 'var' => 'phone',
                                                   'value' => { 'iso' => 'US', 'number' => '202-555-0173', 'prefix' => '+1', 'confirmed' => true,
                                                                'timezone' => 'Not/A/Real/Zone' } }] })
      end

      it 'falls back to the phone-number-derived timezone' do
        expect(helper.timezone).to eq('America/New_York')
      end
    end

    context 'when both the participant value and Phonelib lookup yield no valid zone' do
      # User has_one :phone, so we mutate the existing phone in place rather than
      # creating a second one (which would lead to ambiguous user.phone lookups).
      before do
        user.phone.update_columns(number: '999', prefix: '+999')
      end

      it 'sanity: helper.phone resolves to the unparseable number' do
        expect(helper.phone.full_number).to eq('+999999')
        expect(Phonelib.parse(helper.phone.full_number).timezone).to be_blank
      end

      it 'falls back to the user.time_zone column' do
        user.update!(time_zone: 'America/Los_Angeles')
        expect(helper.timezone).to eq('America/Los_Angeles')
      end

      context 'when user.time_zone is also blank' do
        it 'falls back to UTC' do
          user.update_column(:time_zone, nil)
          expect(helper.timezone).to eq('UTC')
        end
      end
    end
  end

  describe '#insert_links_into_variant' do
    let(:plan) { create(:sms_plan, session: session) }
    let(:no_formula_link) { create(:sms_link, sms_plan: plan, session: session, variable: 'promo') }

    context 'when variant is nil (no-formula mode)' do
      before { no_formula_link }

      it 'creates SmsLinksUser entries for no-formula links only' do
        expect { helper.insert_links_into_variant('Click ::promo::'.dup, plan) }
          .to change(SmsLinksUser, :count).by(1)
      end

      it 'replaces the token with the short link' do
        result = helper.insert_links_into_variant('Click ::promo::'.dup, plan)
        expect(result).to match(%r{/link/})
        expect(result).not_to include('::promo::')
      end

      it 'does not process variant-scoped links' do
        variant = create(:sms_plan_variant, sms_plan: plan)
        create(:sms_link, variant: variant, sms_plan: plan, session: session, variable: 'offer')
        result = helper.insert_links_into_variant('::promo:: ::offer::'.dup, plan)
        expect(result).to include('::offer::')  # variant link not substituted
      end
    end

    context 'when variant is provided (formula mode)' do
      let(:variant) { create(:sms_plan_variant, sms_plan: plan) }
      let!(:variant_link) { create(:sms_link, variant: variant, sms_plan: plan, session: session, variable: 'offer') }

      it 'creates SmsLinksUser entries for variant links only' do
        expect { helper.insert_links_into_variant('Buy ::offer::'.dup, plan, variant) }
          .to change(SmsLinksUser, :count).by(1)
      end

      it 'replaces the token with the short link' do
        result = helper.insert_links_into_variant('Buy ::offer::'.dup, plan, variant)
        expect(result).to match(%r{/link/})
        expect(result).not_to include('::offer::')
      end

      it 'does not process no-formula links' do
        no_formula_link
        result = helper.insert_links_into_variant('::promo:: ::offer::'.dup, plan, variant)
        expect(result).to include('::promo::')  # no-formula link not substituted
      end
    end
  end
end

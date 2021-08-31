# frozen_string_literal: true

require 'rails_helper'

describe Api::CatMh::CreateInterview do
  let(:subject_id) { 'test_subject' }
  let(:language) { 1 }
  let(:number_of_interviews) { 1 }
  let(:timeframe_id) { 1 }
  let(:tests) do
    [
      {
        'type' => 'dep',
        'timeframeID' => 5
      }
    ]
  end

  context 'return correct data' do
    subject { described_class.call(subject_id, number_of_interviews, tests, language, timeframe_id) }

    it 'return correct response' do
      expect(subject).to include(
        {
          'status' => 200,
          'body' => {
            'interviews' => [
              {
                'organizationID' => -1,
                'interviewID' => -1,
                'identifier' => 'identifier',
                'signature' => 'signature'
              }
            ]
          }
        }
      )
    end
  end
end

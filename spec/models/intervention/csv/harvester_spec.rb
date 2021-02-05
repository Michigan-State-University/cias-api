# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention::Csv::Harvester, type: :model do
  let(:subject) { described_class.new([question]) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group_plain, session: session) }

  describe '#collect_data' do
    context 'when single question' do
      let!(:question_body) do
        {
          'data' => [
            { 'value' => '1', 'payload' => '' },
            { 'value' => '2', 'payload' => '' }
          ],
          'variable' => { 'name' => 'test' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test',
              'value' => '1'
            }
          ]
        }
      end
      let!(:question) { create(:question_single, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_single, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test']
        expect(subject.rows).to eq [%W[#{answer.user_session.user_id} #{answer.user_session.user.email} 1]]
      end
    end

    context 'when multiple question' do
      let!(:question_body) do
        {
          'data' => [
            {
              'payload' => '',
              'variable' => { 'name' => 'test_1', 'value': '1' }
            },
            {
              'payload' => '',
              'variable' => { 'name' => 'test_2', 'value': '2' }
            }
          ]
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test_1',
              'value' => '1'
            },
            {
              'var' => 'test_2',
              'value' => '2'
            }
          ]
        }
      end
      let!(:question) { create(:question_multiple, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_multiple, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test_1', 'test_2']
        expect(subject.rows).to eq [%W[#{answer.user_session.user_id} #{answer.user_session.user.email} 1 2]]
      end
    end

    context 'when free response' do
      let!(:question_body) do
        {
          'data' => [
            { 'payload' => '' }
          ],
          'variable' => { 'name' => 'test_1' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test_1',
              'value' => '1'
            }
          ]
        }
      end
      let!(:question) { create(:question_free_response, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_free_response, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test_1']
        expect(subject.rows).to eq [%W[#{answer.user_session.user_id} #{answer.user_session.user.email} 1]]
      end
    end

    context 'when number' do
      let!(:question_body) do
        {
          'data' => [
            { 'payload' => '' }
          ],
          'variable' => { 'name' => 'test_1' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test_1',
              'value' => 1
            }
          ]
        }
      end
      let!(:question) { create(:question_number, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_number, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test_1']
        expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, 1]]
      end
    end

    context 'when grid' do
      let!(:question_body) do
        {
          'data' => [
            {
              'payload' => {
                'rows' => [
                  { 'payload' => '', 'variable' => { 'name' => 'test_1' } },
                  { 'payload' => '', 'variable' => { 'name' => 'test_2' } }
                ],
                'columns' => [
                  { 'payload' => '', 'variable' => { 'value' => '1' } },
                  { 'payload' => '', 'variable' => { 'value' => '2' } }
                ]
              }
            }
          ]
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test_1',
              'value' => '1'
            },
            {
              'var' => 'test_2',
              'value' => '2'
            }
          ]
        }
      end
      let!(:question) { create(:question_grid, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_grid, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test_1', 'test_2']
        expect(subject.rows).to eq [%W[#{answer.user_session.user_id} #{answer.user_session.user.email} 1 2]]
      end
    end

    context 'when slider' do
      let!(:question_body) do
        {
          'data' => [
            { 'payload' => {
              'end_value' => '',
              'start_value' => ''
            }}
          ],
          'variable' => { 'name' => 'test_1' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'test_1',
              'value' => 1
            }
          ]
        }
      end
      let!(:question) { create(:question_slider, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_slider, question: question, body: answer_body) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'test_1']
        expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, 1]]
      end
    end

    context 'when external link' do
      let!(:question_body) do
        {
          'data' => [
            { 'payload' => 'www.test.pl' }
          ],
          'variable' => { 'name' => 'site' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'site',
              'value' => true
            }
          ]
        }
      end
      let!(:question) { create(:question_external_link, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_external_link, question: question, body: answer_body) }

      it 'save variable and the clicking on the link to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'site']
        expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, true]]
      end
    end

    context 'when date' do
      let!(:question_body) do
        {
          'data' => [
            { 'payload' => '' }
          ],
          'variable' => { 'name' => 'date' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'date',
              'value' => '2012-12-12'
            }
          ]
        }
      end
      let!(:question) { create(:question_date, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_date, question: question, body: answer_body) }

      it 'save variable and the clicking on the link to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, 'date']
        expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '2012-12-12']]
      end
    end
  end
end

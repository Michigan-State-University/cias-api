# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention::Csv::Harvester do
  let(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention, variable: 'sess1') }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question) do
    create(:question_file_upload, question_group: question_group,
                                  body: { 'data' => [{ 'payload' => '' }], 'variable' => { 'name' => 'upl1' } })
  end
  let!(:user_session) { create(:user_session, user: participant, session: session) }
  let(:host) { ENV.fetch('WEB_URL', nil) }

  def answer_with(*uploads)
    Answer::FileUpload.create!(
      question: question, user_session: user_session,
      body: { 'data' => [{ 'var' => 'upl1', 'value' => uploads.map(&:id) }] }
    )
  end

  def cell
    harvester = described_class.new(intervention.sessions, nil).collect
    index = harvester.header.index('sess1.upl1')
    [index, index && harvester.rows.first[index]]
  end

  it 'adds one column for the question variable' do
    answer_with(create(:participant_upload, :clean, question: question, user_session: user_session))

    index, = cell
    expect(index).to be_present
  end

  it 'puts every protected link in a single cell' do
    first = create(:participant_upload, :clean, question: question, user_session: user_session)
    second = create(:participant_upload, :clean, question: question, user_session: user_session)
    answer_with(first, second)

    _, value = cell
    expect(value).to eq("#{host}/participant-uploads/#{first.id}\n#{host}/participant-uploads/#{second.id}")
  end

  it 'marks a file still waiting for the scanner' do
    answer_with(create(:participant_upload, question: question, user_session: user_session))

    _, value = cell
    expect(value).to eq('FILE PENDING SCAN')
  end

  it 'marks a file the scanner removed' do
    answer_with(create(:participant_upload, :deleted, question: question, user_session: user_session))

    _, value = cell
    expect(value).to eq('FILE REMOVED BY SECURITY SCAN')
  end

  it 'never leaves the cell empty' do
    clean = create(:participant_upload, :clean, question: question, user_session: user_session)
    pending_upload = create(:participant_upload, question: question, user_session: user_session)
    answer_with(clean, pending_upload)

    _, value = cell
    expect(value.split("\n")).to all(be_present)
  end

  def participant_upload_queries
    count = 0
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      count += 1 if payload[:sql].include?('participant_uploads') && payload[:name] != 'SCHEMA'
    end
    yield
    ActiveSupport::Notifications.unsubscribe(subscription)
    count
  end

  it 'loads every upload in one query, whatever the number of participants' do
    5.times do
      other_session = create(:user_session, user: create(:user, :confirmed, :participant), session: session)
      upload = create(:participant_upload, :clean, question: question, user_session: other_session)
      Answer::FileUpload.create!(
        question: question, user_session: other_session,
        body: { 'data' => [{ 'var' => 'upl1', 'value' => [upload.id] }] }
      )
    end

    queries = participant_upload_queries { described_class.new(intervention.sessions, nil).collect }

    expect(queries).to eq(1)
  end

  it 'exports a link that carries no access token' do
    clean = create(:participant_upload, :clean, question: question, user_session: user_session)
    answer_with(clean)

    _, value = cell
    expect(value).not_to match(/token|signature|expires/i)
  end
end

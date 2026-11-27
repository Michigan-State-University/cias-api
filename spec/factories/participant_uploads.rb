# frozen_string_literal: true

FactoryBot.define do
  factory :participant_upload do
    association :user_session
    association :question, factory: :question_file_upload
    original_filename { 'wyniki badania.png' }
    content_type_detected { 'image/png' }
    byte_size { 72 }
    scan_status { 'pending' }

    transient do
      bytes { "\x89PNG\r\n\x1a\n".b + ("\x00" * 64) }
      upload_filename { 'upload_fixture.png' }
      declared_content_type { 'image/png' }
    end

    after(:build) do |upload, evaluator|
      upload.file.attach(
        io: StringIO.new(evaluator.bytes),
        filename: evaluator.upload_filename,
        content_type: evaluator.declared_content_type
      )
    end

    trait :clean do
      scan_status { 'clean' }
    end

    trait :deleted do
      scan_status { 'deleted' }
      deleted_at { Time.current }
      deletion_reason { 'MALWARE_DETECTED' }
    end
  end
end

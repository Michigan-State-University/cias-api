# frozen_string_literal: true

Aws.config.update(
  region: 'us-east-1',
  credentials: Aws::Credentials.new('test-access-key-id', 'test-secret-access-key'),
  stub_responses: true
)

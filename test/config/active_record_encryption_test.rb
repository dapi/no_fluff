# frozen_string_literal: true

require 'test_helper'

class ActiveRecordEncryptionTest < ActiveSupport::TestCase
  test 'uses application config credentials for encrypted records' do
    config = Rails.application.config.active_record.encryption

    assert_equal ApplicationConfig.active_record_encryption_primary_key, config.primary_key
    assert_equal ApplicationConfig.active_record_encryption_deterministic_key, config.deterministic_key
    assert_equal ApplicationConfig.active_record_encryption_key_derivation_salt, config.key_derivation_salt
  end
end

# frozen_string_literal: true

ActiveRecord::Encryption.configure(
  primary_key: ApplicationConfig.active_record_encryption_primary_key,
  deterministic_key: ApplicationConfig.active_record_encryption_deterministic_key,
  key_derivation_salt: ApplicationConfig.active_record_encryption_key_derivation_salt
)

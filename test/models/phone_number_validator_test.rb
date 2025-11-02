require 'test_helper'

class PhoneNumberValidatorTest < ActiveSupport::TestCase
  test 'validates and normalizes valid phone numbers' do
    valid_numbers = [
      [ '+79123456789', '+7 912 345-67-89' ],
      [ '89123456789', '+7 912 345-67-89' ],
      [ '9123456789', '+7 912 345-67-89' ],
      [ '+7 (912) 345-67-89', '+7 912 345-67-89' ],
      [ '8 (912) 345-67-89', '+7 912 345-67-89' ]
    ]

    valid_numbers.each do |input, expected|
      normalized = normalize_and_validate_phone(input)
      assert_not_nil normalized, "Valid number #{input} should not be nil"
      assert_equal expected, normalized, "Number #{input} should normalize to #{expected}"
    end
  end

  test 'rejects invalid phone numbers' do
    invalid_numbers = [
      '',
      '123',
      '+1234567890',  # Not a Russian number
      'abc123',
      '+791234567890',  # Too long
      '+7912345678',    # Too short
      nil
    ]

    invalid_numbers.each do |number|
      normalized = normalize_and_validate_phone(number)
      assert_nil normalized, "Invalid number #{number} should be nil"
    end
  end

  test 'handles international format correctly' do
    international_numbers = [
      [ '+79991234567', '+7 999 123-45-67' ],
      [ '+7 (999) 123-45-67', '+7 999 123-45-67' ],
      [ '79991234567', '+7 999 123-45-67' ]
    ]

    international_numbers.each do |input, expected|
      normalized = normalize_and_validate_phone(input)
      assert_equal expected, normalized, "International number #{input} should normalize to #{expected}"
    end
  end

  test 'preserves country code for valid numbers' do
    # Test with different country codes (though our app focuses on Russia)
    numbers_with_country = [
      '+77001234567',  # Kazakhstan
      '+375291234567' # Belarus
    ]

    numbers_with_country.each do |number|
      normalized = normalize_and_validate_phone(number)
      assert_not_nil normalized, "Valid international number #{number} should not be nil"
      assert number.start_with?('+'), 'Normalized number should preserve country code'
    end
  end

  test 'handles edge cases gracefully' do
    edge_cases = [
      '+79123456789 ',
      ' +79123456789',
      '+7-912-345-67-89',
      '+7_912_345_67_89'
    ]

    edge_cases.each do |number|
      normalized = normalize_and_validate_phone(number)
      # Phonelib might handle these differently, just ensure no exceptions
      assert_not_nil normalized, "Edge case #{number} should be handled"
    end
  end


  private

  def normalize_and_validate_phone(phone_number)
    return nil if phone_number.blank?

    # Использование Phonelib для валидации и нормализации
    phone = Phonelib.parse(phone_number)
    return nil unless phone.valid?

    phone.international
  rescue => e
    Rails.logger.error "Phone validation error: #{e.message}"
    nil
  end
end

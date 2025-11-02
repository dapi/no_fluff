# frozen_string_literal: true

# Phonelib configuration for phone number validation
Phonelib.default_country = 'RU'
Phonelib.extension_separator = '#'
Phonelib.vanity_conversion = false

# Configure phonelib to be less strict to allow various formats
Phonelib.strict_check = false

# frozen_string_literal: true

# Add Bugsnag context middleware if Bugsnag is available
# Temporarily disabled due to autoload issues
# if defined?(Bugsnag)
#   Rails.application.configure do
#     config.middleware.insert_before 0, BugsnagContext
#   end
# end
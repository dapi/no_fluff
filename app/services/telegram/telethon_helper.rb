# frozen_string_literal: true

require 'json'
require 'open3'

module Telegram
  class TelethonHelper
    class Error < StandardError; end

    DEFAULT_COMMAND = [ 'python3', Rails.root.join('lib/telegram_client/telethon_helper.py').to_s ].freeze

    def initialize(command: DEFAULT_COMMAND, runner: nil)
      @command = command
      @runner = runner || ->(command, input) { Open3.capture3(*command, stdin_data: input) }
    end

    def call(request)
      stdout, _stderr, status = @runner.call(@command, JSON.generate(request))
      raise Error, 'Telegram helper failed' unless status.success?

      response = JSON.parse(stdout, symbolize_names: true)
      raise Error, 'Telegram helper returned an invalid response' unless response.is_a?(Hash)

      response
    rescue JSON::ParserError
      raise Error, 'Telegram helper returned an invalid response'
    end
  end
end

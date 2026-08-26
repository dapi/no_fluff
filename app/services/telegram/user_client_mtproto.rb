# frozen_string_literal: true

require 'uri'

module Telegram
  class UserClientMtproto
    attr_reader :follower_user

    def initialize(follower_user, helper: TelethonHelper.new, proxy_url: ApplicationConfig.telegram_mtproto_proxy)
      @follower_user = follower_user
      @helper = helper
      @proxy = parse_proxy(proxy_url)
      @connected = false
      @authorized = false
    end

    def connect
      result = get_me
      @connected = result[:success]
      @authorized = result[:success]
      result[:success]
    end

    def disconnect
      @connected = false
      @authorized = false
      true
    end

    def connected? = @connected
    def authorized? = @authorized || follower_user.authorized?

    def send_code
      invoke(base_request.merge(operation: 'send_code', session: nil))
    end

    def resend_code(phone_code_hash:, session:)
      invoke(base_request.merge(operation: 'resend_code', phone_code_hash:, session:))
    end

    def confirm_code(code:, phone_code_hash:, session:)
      invoke(base_request.merge(operation: 'confirm_code', code:, phone_code_hash:, session:))
    end

    def get_me(session = follower_user.session_string)
      invoke(base_request.merge(operation: 'get_me', session:))
    end

    private

    def base_request
      credentials = follower_user.api_credentials.symbolize_keys
      { phone: follower_user.phone_number, api_id: credentials.fetch(:api_id), api_hash: credentials.fetch(:api_hash), proxy: @proxy }
    end

    def invoke(request)
      response = @helper.call(request).symbolize_keys
      return success(response) if response[:success]
      return { success: false, error: 'Two-factor authentication required', error_type: :needs_password } if response[:error_type] == 'needs_password' || response[:error_type] == :needs_password

      { success: false, error: 'Telegram authorization request failed', error_type: (response[:error_type] || 'request_failed').to_sym }
    rescue TelethonHelper::Error, KeyError, StandardError => e
      Rails.logger.warn("Telegram authorization helper failed: #{e.class}")
      { success: false, error: 'Telegram authorization request failed', error_type: :request_failed }
    end

    def success(response)
      response.slice(:success, :phone_code_hash, :session, :user, :delivery_type).merge(expires_at: 10.minutes.from_now)
    end

    def parse_proxy(proxy_url)
      return nil if proxy_url.blank? && Rails.env.test?

      uri = URI.parse(proxy_url)
      raise ArgumentError, 'Telegram MTProto proxy must use socks5' unless uri.scheme == 'socks5' && uri.host.present? && uri.port.present?

      { scheme: uri.scheme, host: uri.host, port: uri.port }.tap do |proxy|
        proxy[:username] = URI.decode_www_form_component(uri.user) if uri.user.present?
        proxy[:password] = URI.decode_www_form_component(uri.password) if uri.password.present?
      end
    rescue URI::InvalidURIError
      raise ArgumentError, 'Telegram MTProto proxy is invalid'
    end
  end
end

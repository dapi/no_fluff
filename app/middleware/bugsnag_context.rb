# Middleware для добавления контекста в Bugsnag
class BugsnagContext
  def initialize(app)
    @app = app
  end

  def call(env)
    # Add request context to Bugsnag
    if defined?(Bugsnag)
      request = ActionDispatch::Request.new(env)

      Bugsnag.add_metadata(:request, {
        url: request.url,
        user_agent: request.user_agent,
        remote_ip: request.remote_ip,
        request_method: request.method,
        path: request.path,
        query_string: request.query_string
      })

      # Add user context if available
      if request.session.present? && request.session['user_id'].present?
        Bugsnag.add_metadata(:user, {
          id: request.session['user_id']
        })
      end
    end

    @app.call(env)
  rescue => exception
    # Ensure Bugsnag gets notified of unhandled exceptions
    if defined?(Bugsnag)
      Bugsnag.notify(exception, metadata: {
        context: "Rack Middleware",
        url: env['REQUEST_URL'] || env['PATH_INFO'],
        method: env['REQUEST_METHOD'],
        user_agent: env['HTTP_USER_AGENT'],
        remote_ip: env['REMOTE_ADDR']
      })
    end

    raise exception
  end
end
module Tenancy
  class Middleware
    UNSERVED = "Unknown tenant".freeze
    TENANTLESS = %w[/up].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      return @app.call(env) if TENANTLESS.include?(request.path)

      tenant = Tenant.resolve(request.host)

      return unserved if tenant.nil?

      Tenant.switch(tenant) { @app.call(env) }
    end

    private

      def unserved
        [
          404,
          { "content-type" => "text/plain; charset=utf-8", "cache-control" => "no-store" },
          [ UNSERVED ]
        ]
      end
  end
end

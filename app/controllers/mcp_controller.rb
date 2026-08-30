class McpController < ApplicationController
  include ProtectedResource

  INSTRUCTIONS = <<~TEXT.freeze
    things is one searchable index across everything its owner keeps, wherever it lives.

    A thing is a reference, not the bytes: the catalog holds where something lives and what
    analysis understood about it, while the original stays in the resource it came from.
    So searching is cheap and reading the bytes back means exporting them.

    Start with search_things. Use list_resources to see where things come from, and
    describe_resource before command_resource — each resource type has its own vocabulary.

    Credentials never travel through a tool call. Connecting a resource happens in the
    browser, and nothing here will accept a secret as an argument.
  TEXT

  skip_forgery_protection

  before_action :authorize

  def handle
    reply = server.handle_json(request.raw_post)

    if reply
      render json: reply
    else
      head :accepted
    end
  end

  def unsupported
    head :method_not_allowed
  end

  private

    def authorize
      grant
    rescue Grant::Denied, Issuer::Unconfigured => e
      challenge(e.message)
    end

    def grant
      @grant ||= Grant.from_authorization(
        request.authorization, tenant: current_tenant, audience: resource_url
      )
    end

    def server
      MCP::Server.new(
        name: "things",
        title: "things",
        instructions: INSTRUCTIONS,
        tools: grant.tools,
        server_context: { tenant: current_tenant, grant: grant }
      )
    end
end

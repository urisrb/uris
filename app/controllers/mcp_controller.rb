class McpController < ApplicationController
  include Granted

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

    # A connector is handed a URL and nothing else, so an unauthenticated call
    # has to be answered with the challenge rather than sent to a login page.
    def presented?
      true
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

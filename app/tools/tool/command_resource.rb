module Tool
  class CommandResource < Base
    tool_name "command_resource"
    scope "resources:command"

    description <<~TEXT
      Run one command against one resource, in its own vocabulary. Call describe_resource
      first for the commands it accepts and their arguments. Credentials cannot be set
      this way — connecting a resource happens in the browser, never in a tool call.
    TEXT

    input_schema(
      properties: {
        id: { type: "string", description: "The resource's id." },
        command: { type: "string", description: "A command name from describe_resource." },
        arguments: { type: "object", description: "Arguments for that command." }
      },
      required: [ "id", "command" ]
    )

    def self.call(id:, command:, server_context:, arguments: {})
      respond(server_context, { id: id, command: command, arguments: arguments }) do
        resource = resource!(id)

        { id: resource.id.to_s, command: command, result: resource.command(command, arguments) }
      end
    end
  end
end

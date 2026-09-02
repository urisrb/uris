module Tool
  class EnrollResource < Base
    tool_name "enroll_resource"
    scope "resources:command"

    description <<~TEXT
      Begin connecting a resource whose credential is held by the authorization server —
      a Google account, for instance. Returns a short-lived link to open in a browser.
      The link authorizes nothing on its own: opening it requires signing in, and the
      credential is captured there rather than here, because a secret in a tool call is
      a secret in the transcript. Nothing exists until the link is followed.
    TEXT

    input_schema(
      properties: {
        type: { type: "string", description: "The resource type, such as oauth-google." },
        key: { type: "string", description: "A name unique among resources of this type." },
        name: { type: "string", description: "What to call it in listings." }
      },
      required: [ "type", "key" ]
    )

    def self.call(type:, key:, name: nil, server_context:)
      respond(server_context, { type: type, key: key }) do
        enrollment = Enrollment.open!(type: type, key: key, name: name)

        {
          type: enrollment.type,
          key: enrollment.key,
          provider: enrollment.provider,
          url: enrollment.url(Current.origin),
          expires_in: Enrollment::WINDOW.to_i,
          note: "open this in a browser and sign in — it captures the credential and creates the resource"
        }
      end
    end
  end
end

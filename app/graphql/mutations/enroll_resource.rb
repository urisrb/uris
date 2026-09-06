# frozen_string_literal: true

module Mutations
  class EnrollResource < BaseMutation
    argument :type, String, required: true
    argument :key, String, required: true
    argument :name, String, required: false

    field :url, String, null: false,
          description: "Open it in a browser. Nothing exists until it is followed."
    field :expires_in, Integer, null: false

    def resolve(type:, key:, name: nil)
      enrollment = Enrollment.open!(type: type, key: key.to_s.strip, name: name.presence&.strip)

      { url: enrollment.url(Current.origin), expires_in: Enrollment::WINDOW.to_i }
    rescue ArgumentError => e
      refused(e.message)
    end
  end
end

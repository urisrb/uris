# frozen_string_literal: true

module Mutations
  class SetSetting < BaseMutation
    argument :key, String, required: true
    argument :value, String, required: true

    field :setting, Types::SettingType, null: false

    def resolve(key:, value:)
      definition = definition!(key)
      grant = context[:grant]

      unless grant&.permits?(definition.writes)
        refused("this token does not carry #{definition.writes}")
      end

      Setting.write!(definition.key, value, subject: grant.subject)

      { setting: stated(definition, value) }
    rescue ActiveRecord::RecordInvalid => e
      refused(e.record.errors.full_messages.to_sentence)
    end

    private

      def definition!(key)
        Setting.definition!(key)
      rescue Setting::Unknown => e
        refused(e.message)
      end

      def stated(definition, value)
        definition.to_h.merge(value: value)
      end
  end
end

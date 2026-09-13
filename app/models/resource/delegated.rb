class Resource
  module Delegated
    extend ActiveSupport::Concern

    LEEWAY = 60.seconds

    class_methods do
      def delegated?
        true
      end

      def delegated_provider
        raise NotImplementedError, "#{name} names no provider in masks"
      end
    end

    def delegated?
      true
    end

    def provider_key
      self.class.delegated_provider
    end

    def connect_path
      Rails.application.routes.url_helpers.resource_connect_path(self) if delegated?
    end

    def delegation
      credentials.to_h["delegation"].to_h
    end

    def connected?
      delegation["connection"].present? && delegation["secret"].present?
    end

    def needs_connect?
      !connected? || needs_connect_at.present?
    end

    def connect!(held, by:)
      self.credentials = credentials.to_h.except("upstream").merge(
        "delegation" => {
          "connection" => held.connection, "provider" => held.provider,
          "subject" => held.subject, "secret" => held.secret
        }
      )
      self.connected_by = by
      self.needs_connect_at = nil
      save!

      self
    end

    def upstream_token
      held = credentials.to_h["upstream"].to_h
      return held["access_token"] if fresh?(held)

      locked, outcome = Resource.transaction do
        held = Resource.lock.find(id)

        [ held, held.send(:renew) ]
      end

      self.credentials = locked.credentials
      self.needs_connect_at = locked.needs_connect_at
      clear_attribute_changes(%i[credentials needs_connect_at])

      raise outcome if outcome.is_a?(Exception)

      credentials.to_h.dig("upstream", "access_token")
    end

    alias token upstream_token

    def token_expired!
      return false unless connected?

      update_columns(credentials: credentials.to_h.except("upstream"))

      true
    end

    private

      def fresh?(held)
        held["access_token"].present? && held["expires_at"].to_i > (Time.current + LEEWAY).to_i
      end

      def renew
        return nil if fresh?(credentials.to_h["upstream"].to_h)
        return Resource::Unusable.new("#{key} is not connected to #{provider_key} yet — connect it") unless connected?

        upstream = Delegations.for(tenant).token(delegation["secret"], connection: delegation["connection"])

        remember(upstream.secret, { "access_token" => upstream.access_token, "expires_at" => upstream.expires_at },
                 needs_connect_at: nil)

        nil
      rescue Delegations::Refused => e
        remember(e.secret, needs_connect_at: Time.current)

        Resource::Unusable.new("#{key}: masks will no longer release #{provider_key} for it (#{e.message}) — connect it again")
      rescue Delegations::Unavailable => e
        remember(e.secret)

        Resource::Failed.new("#{key}: #{e.message}")
      rescue Tenant::Unconfigured, Masks::Client::Error => e
        Resource::Failed.new("#{key}: #{e.message}")
      end

      def remember(secret, upstream = nil, **columns)
        held = credentials.to_h
        held = held.merge("delegation" => held["delegation"].to_h.merge("secret" => secret)) if secret.present?
        held = upstream ? held.merge("upstream" => upstream) : held.except("upstream")

        update_columns(credentials: held, **columns)
      end
  end
end

# frozen_string_literal: true

module Types
  class FeedType < Types::BaseObject
    grants "uris:catalog:read"

    SUMMARY = 400
    CONNECTED = 200

    field :id, ID, null: false
    field :type, String, null: false,
          description: "What it is, and how it renders: uris:file, uris:note, uris:feed, uris:tag, uris:mime."
    field :key, String, null: false,
          description: "Its name within its type — README.md, text/markdown, /buy."
    field :origin, String, null: false,
          description: "resource when synced from one, feed when an analysis minted it."
    field :title, String
    field :mime, String, description: "The content type of the bytes, when it has any."
    field :references, [ Types::ReferenceType ], null: false
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
    field :note, String, description: "What you wrote about it, in your own words."
    field :summary, String,
          description: "What a model made of it. The extracted text, until one has run."
    field :keywords, [ String ], null: false,
          description: "Search terms a model drew out of it."
    field :thumbnail_url, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    field :connected_count, Integer, null: false
    field :connected, [ Types::FeedType ], null: false
    field :tags, [ Types::FeedType ], null: false
    field :mimes, [ Types::FeedType ], null: false,
          description: "The content types it was filed under, as feeds of their own."
    field :parent, Types::FeedType, description: "The file it was extracted from, when it was."
    field :children, [ Types::FeedType ], null: false,
          description: "What was extracted from it — the attachments of a message, the files of an archive."
    field :staged, Boolean, null: false,
          description: "Uploaded, and still waiting for the pass to decide where it is stored."
    field :schedule, Types::ScheduleType
    field :analyses, [ Types::AnalysisType ], null: false

    def summary
      object.summary || object.body_text&.squish&.truncate(SUMMARY)
    end

    def keywords
      object.keywords
    end

    def connected_count = object.edges.count

    def staged = object.staged?

    def children
      object.children.limit(CONNECTED)
    end

    def connected
      object.connected.order(created_at: :desc).limit(CONNECTED)
    end

    def tags
      object.tags.order(:key)
    end

    def mimes
      object.mimes.order(:key)
    end

    def analyses
      object.analyses.newest_first.limit(20)
    end

    def thumbnail_url
      thumbnail = object.references.find { |held| held.role == Reference::THUMBNAIL }

      "/references/#{thumbnail.id}/content" if thumbnail
    end
  end
end

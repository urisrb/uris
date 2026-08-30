require "aws-sdk-s3"

class Resource
  class S3 < Resource
    def self.capabilities
      [ :storage ]
    end

    def self.command_schema
      {
        list: { prefix: "string?", continuation_token: "string?" },
        get: { key: "string", version_id: "string?" },
        put: { key: "string", body: "bytes" }
      }
    end

    MAX_TEXT = 100_000

    def bucket
      key
    end

    def command_list(prefix: nil, continuation_token: nil)
      page = s3 do |client|
        client.list_objects_v2(
          bucket: bucket,
          prefix: prefix.presence || details["prefix"],
          continuation_token: continuation_token.presence,
          max_keys: 1000
        )
      end

      {
        "objects" => page.contents.map do |object|
          { "key" => object.key, "size" => object.size, "last_modified" => object.last_modified }
        end,
        "continuation_token" => page.next_continuation_token
      }
    end

    def command_get(key:, version_id: nil)
      bytes = s3 { |client| client.get_object(bucket: bucket, key: key, version_id: version_id.presence) }.body.read
      text = bytes.dup.force_encoding(Encoding::UTF_8)

      if text.valid_encoding?
        { "key" => key, "size" => bytes.bytesize, "text" => text.truncate(MAX_TEXT) }
      else
        { "key" => key, "size" => bytes.bytesize, "text" => nil,
          "note" => "binary — sync it into the catalog or export it instead" }
      end
    end

    def command_put(key:, body:)
      upload(key, body)
    end

    def check!
      s3 { |client| client.head_bucket(bucket: bucket) }
      true
    end

    def each_page(cursor: nil, prefix: nil)
      loop do
        page = s3 do |client|
          client.list_objects_v2(
            bucket: bucket,
            prefix: prefix || details["prefix"],
            continuation_token: cursor.presence,
            max_keys: 1000
          )
        end

        cursor = page.next_continuation_token
        yield page.contents, cursor

        break unless page.is_truncated
      end
    end

    def locator_for(object)
      { "bucket" => bucket, "key" => object.key, "etag" => object.etag&.delete('"') }
    end

    def locator_key_for(object)
      object.key
    end

    def download(locator)
      s3 { |client| client.get_object(bucket: locator.fetch("bucket"), key: locator.fetch("key")) }.body
    end

    def upload(key, body)
      s3 { |client| client.put_object(bucket: bucket, key: key, body: body) }
      { "bucket" => bucket, "key" => key }
    end

    def client
      @client ||= Aws::S3::Client.new(
        endpoint: details.fetch("endpoint"),
        region: details.fetch("region", "us-east-1"),
        access_key_id: credentials.fetch("access_key_id"),
        secret_access_key: credentials.fetch("secret_access_key"),
        force_path_style: details.fetch("force_path_style", true)
      )
    end

    private

      def s3
        yield client
      rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
        raise Resource::Failed, "#{key}: #{e.message}"
      end
  end
end

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

    def bucket
      key
    end

    def check!
      client.head_bucket(bucket: bucket)
      true
    end

    def each_page(cursor: nil, prefix: nil)
      loop do
        page = client.list_objects_v2(
          bucket: bucket,
          prefix: prefix || details["prefix"],
          continuation_token: cursor.presence,
          max_keys: 1000
        )

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
      client.get_object(bucket: locator.fetch("bucket"), key: locator.fetch("key")).body
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
  end
end

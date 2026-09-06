require "aws-sdk-s3"
require "monitor"
require "stringio"

class FakeS3
  ENDPOINT = "http://s3.fake".freeze

  Object = Struct.new(:key, :size, :last_modified, :etag)
  Listing = Struct.new(:contents, :next_continuation_token, :is_truncated)
  Body = Struct.new(:body, :etag)
  Written = Struct.new(:etag)

  class << self
    def store
      @store ||= new
    end

    def reset!
      @store = nil
    end

    def for(endpoint)
      endpoint.to_s == ENDPOINT ? store : Unreachable.new(endpoint)
    end
  end

  class Unreachable
    def initialize(endpoint)
      @endpoint = endpoint
    end

    def method_missing(name, *, **)
      raise Seahorse::Client::NetworkingError.new(
        Errno::ECONNREFUSED.new(@endpoint.to_s), "could not reach #{@endpoint}"
      )
    end

    def respond_to_missing?(*) = true
  end

  def initialize
    @lock = Monitor.new
    @buckets = {}
  end

  def create_bucket(bucket:, **)
    @lock.synchronize { @buckets[bucket] ||= {} }

    Written.new(nil)
  end

  def delete_bucket(bucket:, **)
    @lock.synchronize do
      held!(bucket)
      @buckets.delete(bucket)
    end

    Written.new(nil)
  end

  def head_bucket(bucket:, **)
    @lock.synchronize { held!(bucket) }

    Written.new(nil)
  end

  def put_object(bucket:, key:, body:, **)
    bytes = body.respond_to?(:read) ? body.read : body.to_s

    @lock.synchronize do
      @buckets[bucket] ||= {}
      @buckets[bucket][key] = { bytes: bytes, at: Time.current, etag: digest(bytes) }
    end

    Written.new(digest(bytes))
  end

  def get_object(bucket:, key:, **)
    held = @lock.synchronize do
      held!(bucket)
      @buckets[bucket][key] or raise missing(Aws::S3::Errors::NoSuchKey, "no key #{key}")
    end

    Body.new(StringIO.new(held[:bytes]), held[:etag])
  end

  def delete_object(bucket:, key:, **)
    @lock.synchronize do
      held!(bucket)
      @buckets[bucket].delete(key)
    end

    Written.new(nil)
  end

  def list_objects_v2(bucket:, prefix: nil, continuation_token: nil, max_keys: 1000, **)
    @lock.synchronize do
      held!(bucket)

      keys = @buckets[bucket].keys.sort
      keys = keys.select { |key| key.start_with?(prefix.to_s) } if prefix.present?
      keys = keys.drop_while { |key| key <= continuation_token } if continuation_token.present?

      page = keys.first(max_keys)
      more = keys.size > page.size

      Listing.new(page.map { |key| object_for(bucket, key) }, more ? page.last : nil, more)
    end
  end

  private

    def object_for(bucket, key)
      held = @buckets[bucket][key]

      Object.new(key, held[:bytes].bytesize, held[:at], held[:etag])
    end

    def held!(bucket)
      return if @buckets.key?(bucket)

      raise missing(Aws::S3::Errors::NoSuchBucket, "no bucket #{bucket}")
    end

    def missing(kind, message)
      kind.new(Seahorse::Client::RequestContext.new, message)
    end

    def digest(bytes)
      Digest::MD5.hexdigest(bytes)
    end
end

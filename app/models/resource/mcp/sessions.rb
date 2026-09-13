require "connection_pool"

class Resource
  class Mcp
    module Sessions
      SIZE = 4
      WAIT = 30
      IDLE = 5.minutes

      Held = Struct.new(:resource_id, :pool, :used_at)

      @lock = Mutex.new
      @held = {}

      class << self
        def with(resource_id, fingerprint, build)
          held = claim(resource_id, fingerprint, build)

          held.pool.with do |client|
            client.connect unless client.connected?
            yield client
          ensure
            held.used_at = monotonic
          end
        end

        def forget(resource_id)
          close_all(@lock.synchronize { take { |_, held| held.resource_id == resource_id } })
        end

        def clear!
          close_all(@lock.synchronize { take { true } })
        end

        def count
          @lock.synchronize { @held.size }
        end

        private

          def claim(resource_id, fingerprint, build)
            stale = []

            held = @lock.synchronize do
              now = monotonic
              stale = take do |key, other|
                key != fingerprint && (other.resource_id == resource_id || now - other.used_at > IDLE)
              end

              @held[fingerprint] ||= Held.new(
                resource_id, ConnectionPool.new(size: SIZE, timeout: WAIT) { build.call }, now
              )
            end

            close_all(stale)
            held
          end

          def take
            @held.select { |key, held| yield key, held }.keys.map { |key| @held.delete(key) }
          end

          def close_all(helds)
            helds.each { |held| held.pool.shutdown { |client| close(client) } }
          end

          def close(client)
            client.transport.close if client.transport.respond_to?(:close)
          rescue StandardError
            nil
          end

          def monotonic
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
      end
    end
  end
end

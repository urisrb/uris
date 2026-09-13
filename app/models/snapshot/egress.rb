require "socket"
require "uri"

class Snapshot
  class Egress
    HEAD = 32.kilobytes
    WAIT = 10
    CHUNK = 64.kilobytes

    REFUSED = "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".freeze
    MALFORMED = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".freeze
    UNREACHABLE = "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".freeze
    ESTABLISHED = "HTTP/1.1 200 Connection Established\r\n\r\n".freeze

    DROPPED = %w[connection proxy-connection proxy-authorization keep-alive].freeze

    def self.open
      egress = new.start
      yield egress
    ensure
      egress&.stop
    end

    def initialize
      @sockets = Concurrent::Set.new
      @threads = Concurrent::Set.new
    end

    def start
      @server = TCPServer.new("127.0.0.1", 0)
      @acceptor = Thread.new { accept }
      self
    end

    def port
      @server.addr[1]
    end

    def address
      "http://127.0.0.1:#{port}"
    end

    def stop
      @acceptor&.kill
      @server&.close
      @sockets.each { |socket| socket.close unless socket.closed? }
      @threads.each(&:kill)
    rescue IOError
      nil
    end

    private

      def accept
        loop do
          client = @server.accept
          held(client)
          spawn { serve(client) }
        end
      rescue IOError, Errno::EBADF
        nil
      end

      def spawn(&block)
        thread = Thread.new do
          block.call
        ensure
          @threads.delete(Thread.current)
        end
        @threads << thread
      end

      def held(socket)
        @sockets << socket
        socket
      end

      def serve(client)
        head, rest = head_of(client)
        return refuse(client, MALFORMED) if head.nil?

        verb, target, version = head.lines.first.to_s.split(" ", 3)
        return refuse(client, MALFORMED) if verb.blank? || target.blank?

        verb.upcase == "CONNECT" ? tunnel(client, target, rest) : forward(client, verb, target, version, head, rest)
      rescue PublicAddress::Blocked, PublicAddress::Unresolvable
        refuse(client, REFUSED)
      rescue SystemCallError, IOError, SocketError, Timeout::Error
        refuse(client, UNREACHABLE)
      ensure
        close(client)
      end

      def tunnel(client, target, rest)
        uri = URI.parse("//#{target}")
        return refuse(client, MALFORMED) if uri.hostname.blank? || uri.port.nil?

        upstream = dial(uri.hostname, uri.port)
        client.write(ESTABLISHED)
        upstream.write(rest) unless rest.empty?
        pipe(client, upstream)
      rescue URI::InvalidURIError
        refuse(client, MALFORMED)
      end

      def forward(client, verb, target, version, head, rest)
        uri = URI.parse(target)
        return refuse(client, MALFORMED) unless uri.instance_of?(URI::HTTP) && uri.hostname.present?

        upstream = dial(uri.hostname, uri.port)
        upstream.write(rewritten(verb, uri, version, head))
        upstream.write(rest) unless rest.empty?
        pipe(client, upstream)
      rescue URI::InvalidURIError
        refuse(client, MALFORMED)
      end

      def rewritten(verb, uri, version, head)
        path = uri.request_uri.presence || "/"
        headers = head.lines.drop(1).map(&:chomp).reject(&:empty?).reject do |line|
          DROPPED.include?(line.split(":", 2).first.to_s.strip.downcase)
        end

        [ "#{verb} #{path} #{version.to_s.strip.presence || 'HTTP/1.1'}", *headers, "Connection: close", "", "" ].join("\r\n")
      end

      def dial(host, port)
        raise PublicAddress::Blocked, "port #{port} is not a port" unless port.between?(1, 65_535)

        address = PublicAddress.address_for!(host.delete_prefix("[").delete_suffix("]"))
        held(Socket.tcp(address, port, connect_timeout: WAIT))
      end

      def head_of(client)
        buffer = +""

        until (ending = buffer.index("\r\n\r\n"))
          return nil if buffer.bytesize > HEAD
          return nil unless client.wait_readable(WAIT)

          buffer << client.readpartial(CHUNK)
        end

        [ buffer.byteslice(0, ending + 4), buffer.byteslice(ending + 4..) || "" ]
      rescue EOFError
        nil
      end

      def pipe(client, upstream)
        outward = Thread.new { copy(client, upstream) }
        copy(upstream, client)
      ensure
        close(upstream)
        close(client)
        outward&.join(1)
        outward&.kill
      end

      def copy(from, to)
        loop { to.write(from.readpartial(CHUNK)) }
      rescue EOFError, IOError, SystemCallError
        close(to)
      end

      def refuse(client, answer)
        client.write(answer) unless client.closed?
      rescue IOError, SystemCallError
        nil
      end

      def close(socket)
        return if socket.nil?

        socket.close unless socket.closed?
        @sockets.delete(socket)
      rescue IOError
        nil
      end
  end
end

require "socket"

class FakeDavServer
  ROOT = "/dav/".freeze

  class << self
    def current
      @current ||= new
    end
  end

  attr_reader :port

  def initialize
    @lock = Mutex.new
    @files = {}
    @collections = []
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def origin
    "http://127.0.0.1:#{port}"
  end

  def url
    "#{origin}#{ROOT}"
  end

  def put(path, contents, type: "application/octet-stream")
    @lock.synchronize do
      @files[path] = { body: contents, type: type, etag: SecureRandom.hex(8) }
      add_collections(path)
    end
  end

  def read(path)
    @lock.synchronize { @files.dig(path, :body) }
  end

  def paths
    @lock.synchronize { @files.keys.sort }
  end

  def reset!
    @lock.synchronize { @files.clear; @collections = [] }
  end

  private

    def add_collections(path)
      parts = path.split("/")[0..-2].to_a
      parts.each_index { |index| @collections |= [ parts[0..index].join("/") ] }
    end

    def serve
      loop do
        socket = @server.accept
        Thread.new { respond(socket) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def respond(socket)
      method, target, = socket.gets.to_s.split(" ")
      headers = {}

      while (line = socket.gets) && line.strip != ""
        name, value = line.split(":", 2)
        headers[name.to_s.downcase.strip] = value.to_s.strip
      end

      body = socket.read(headers["content-length"].to_i) if headers["content-length"]
      path = decoded(target.to_s)

      socket.print(reply(method, path, body, headers))
    rescue Errno::EPIPE, IOError
      nil
    ensure
      socket.close rescue nil
    end

    def decoded(target)
      URI.decode_www_form_component(URI.parse(target).path.to_s).delete_prefix(ROOT).chomp("/")
    rescue URI::InvalidURIError
      ""
    end

    def reply(method, path, body, headers)
      return status("401 Unauthorized") unless headers["authorization"].to_s.start_with?("Basic ")

      case method
      when "PROPFIND" then propfind(path)
      when "GET" then get(path)
      when "PUT" then put_at(path, body)
      when "MKCOL" then mkcol(path)
      else status("405 Method Not Allowed")
      end
    end

    def propfind(path)
      entries = @lock.synchronize do
        return status("404 Not Found") unless path.empty? || @collections.include?(path)

        [ collection_xml(path) ] + children(path)
      end

      xml = %(<?xml version="1.0" encoding="utf-8"?>\n) +
            %(<d:multistatus xmlns:d="DAV:">#{entries.join}</d:multistatus>)

      status("207 Multi-Status", xml, "application/xml")
    end

    def children(path)
      inside = ->(candidate) { path.empty? ? !candidate.include?("/") : candidate.start_with?("#{path}/") && candidate.delete_prefix("#{path}/").exclude?("/") }

      @collections.select(&inside).sort.map { |name| collection_xml(name) } +
        @files.keys.select(&inside).sort.map { |name| file_xml(name) }
    end

    def collection_xml(path)
      href = path.empty? ? ROOT : "#{ROOT}#{escape(path)}/"

      <<~XML
        <d:response><d:href>#{href}</d:href><d:propstat><d:prop>
          <d:resourcetype><d:collection/></d:resourcetype>
        </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
      XML
    end

    def file_xml(path)
      file = @files.fetch(path)

      <<~XML
        <d:response><d:href>#{ROOT}#{escape(path)}</d:href><d:propstat><d:prop>
          <d:resourcetype/>
          <d:getcontentlength>#{file[:body].bytesize}</d:getcontentlength>
          <d:getlastmodified>Mon, 30 Aug 2027 12:00:00 GMT</d:getlastmodified>
          <d:getetag>"#{file[:etag]}"</d:getetag>
          <d:getcontenttype>#{file[:type]}</d:getcontenttype>
        </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
      XML
    end

    def escape(path)
      path.split("/").map { |part| ERB::Util.url_encode(part) }.join("/")
    end

    def get(path)
      file = @lock.synchronize { @files[path] }
      return status("404 Not Found") if file.nil?

      status("200 OK", file[:body], file[:type], etag: file[:etag])
    end

    def put_at(path, body)
      etag = SecureRandom.hex(8)

      @lock.synchronize do
        parent = path.split("/")[0..-2].to_a.join("/")
        return status("409 Conflict") unless parent.empty? || @collections.include?(parent)

        @files[path] = { body: body.to_s, type: "application/octet-stream", etag: etag }
      end

      status("201 Created", "", "text/plain", etag: etag)
    end

    def mkcol(path)
      @lock.synchronize do
        return status("405 Method Not Allowed") if @collections.include?(path)

        @collections |= [ path ]
      end

      status("201 Created")
    end

    def status(line, body = "", type = "text/plain", etag: nil)
      headers = [ "HTTP/1.1 #{line}", "Content-Type: #{type}", "Content-Length: #{body.bytesize}" ]
      headers << %(ETag: "#{etag}") if etag

      (headers + [ "Connection: close", "", body ]).join("\r\n")
    end
end

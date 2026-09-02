require "socket"
require "json"

class FakeBrokerServer
  attr_reader :requests

  class << self
    def current
      @current ||= new
    end
  end

  def initialize
    @requests = []
    @responses = {}
    @lock = Mutex.new
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def reset!
    @lock.synchronize do
      @requests = []
      @responses = {}
    end
  end

  def on(path, status: 200, body: {})
    @lock.synchronize { @responses[path] = { status: status, body: body } }
  end

  def authorizations_for(path)
    @lock.synchronize { @requests.select { |one| one[:path] == path }.map { |one| one[:authorization] } }
  end

  def bodies_for(path)
    @lock.synchronize { @requests.select { |one| one[:path] == path }.map { |one| one[:body] } }
  end

  def count_for(path)
    @lock.synchronize { @requests.count { |one| one[:path] == path } }
  end

  private

    def serve
      loop do
        socket = @server.accept
        Thread.new { respond(socket) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def respond(socket)
      line = socket.gets.to_s
      length = 0
      authorization = nil

      while (header = socket.gets) && header.strip != ""
        name, value = header.split(":", 2)
        length = value.to_i if name.to_s.downcase == "content-length"
        authorization = value.to_s.strip if name.to_s.downcase == "authorization"
      end

      path = line.split(" ")[1].to_s.split("?").first
      raw = length.positive? ? socket.read(length).to_s : ""

      @lock.synchronize do
        @requests << { path: path, authorization: authorization, body: Rack::Utils.parse_query(raw) }
      end

      found = @lock.synchronize { @responses[path] }
      found = { status: 404, body: { "error" => "not_found" } } if found.nil?

      payload = found[:body].is_a?(String) ? found[:body] : JSON.generate(found[:body])

      socket.print [
        "HTTP/1.1 #{found[:status]}",
        "Content-Type: application/json",
        "Content-Length: #{payload.bytesize}",
        "Connection: close",
        "", payload
      ].join("\r\n")
    rescue Errno::EPIPE, IOError
      nil
    ensure
      socket.close rescue nil
    end
end

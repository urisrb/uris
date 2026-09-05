require "socket"
require "json"

class FakeModelServer
  class << self
    def current
      @current ||= new
    end
  end

  attr_reader :port

  def initialize
    @lock = Mutex.new
    @served = []
    @answers = []
    @prompts = []
    @attachments = []
    @counts = Hash.new(0)
    @authorizations = Hash.new { |hash, key| hash[key] = [] }
    @hang = 0
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def origin
    "http://127.0.0.1:#{port}"
  end

  def base_url
    "#{origin}/v1"
  end

  def reset!
    @lock.synchronize do
      @served = []
      @answers = []
      @prompts = []
      @attachments = []
      @counts = Hash.new(0)
      @authorizations = Hash.new { |hash, key| hash[key] = [] }
      @hang = 0
    end
    self
  end

  def serves(*models)
    @lock.synchronize { @served = models.flatten.map(&:to_s) }
    self
  end

  def answer(content)
    @lock.synchronize { @answers << { content: content.to_s } }
    self
  end

  def answer_json(payload)
    answer(JSON.generate(payload))
  end

  def refuse(status, body: "")
    @lock.synchronize { @answers << { status: status, body: body } }
    self
  end

  def hang(seconds)
    @lock.synchronize { @hang = seconds }
    self
  end

  def prompts
    @lock.synchronize { @prompts.dup }
  end

  def attachments
    @lock.synchronize { @attachments.dup }
  end

  def count_for(path)
    @lock.synchronize { @counts[path] }
  end

  def authorizations_for(path)
    @lock.synchronize { @authorizations[path].dup }
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
      request = socket.gets.to_s
      headers = {}

      while (line = socket.gets) && line.strip != ""
        name, value = line.split(":", 2)
        headers[name.to_s.strip.downcase] = value.to_s.strip
      end

      path = request.split(" ")[1].to_s
      length = headers["content-length"].to_i
      body = length.positive? ? socket.read(length).to_s : ""

      pause = @lock.synchronize do
        @counts[path] += 1
        @authorizations[path] << headers["authorization"]
        @hang
      end

      sleep(pause) if pause.positive?

      socket.print(route(path, body))
    rescue Errno::EPIPE, IOError
      nil
    ensure
      socket.close rescue nil
    end

    def route(path, body)
      case path
      when %r{/models\z} then rendered(200, JSON.generate(models_payload))
      when %r{/chat/completions\z} then completion(body)
      else rendered(404, "")
      end
    end

    def models_payload
      { "object" => "list", "data" => @lock.synchronize { @served }.map { |id| { "id" => id } } }
    end

    def completion(body)
      record_prompt(body)
      queued = @lock.synchronize { @answers.shift }

      return rendered(200, JSON.generate(completion_payload(""))) if queued.nil?
      return rendered(queued[:status], queued[:body]) if queued.key?(:status)

      rendered(200, JSON.generate(completion_payload(queued[:content])))
    end

    def completion_payload(content)
      { "choices" => [ { "message" => { "role" => "assistant", "content" => content } } ] }
    end

    def record_prompt(body)
      parsed = JSON.parse(body)
      user = Array(parsed["messages"]).reverse.find { |message| message["role"] == "user" }
      content = user.to_h["content"]

      @lock.synchronize do
        @prompts << spoken(content)
        @attachments << attached(content)
      end
    rescue JSON::ParserError
      @lock.synchronize do
        @prompts << body.to_s
        @attachments << []
      end
    end

    def spoken(content)
      return content.to_s unless content.is_a?(Array)

      content.filter_map { |part| part["text"] }.join("\n")
    end

    def attached(content)
      return [] unless content.is_a?(Array)

      content.filter_map { |part| part.dig("image_url", "url") }
    end

    def rendered(status, body)
      [
        "HTTP/1.1 #{status} #{reason(status)}",
        "Content-Type: application/json",
        "Content-Length: #{body.to_s.bytesize}",
        "Connection: close",
        "",
        body.to_s
      ].join("\r\n")
    end

    def reason(status)
      { 200 => "OK", 400 => "Bad Request", 401 => "Unauthorized", 404 => "Not Found",
        429 => "Too Many Requests", 500 => "Internal Server Error", 503 => "Service Unavailable" }
        .fetch(status, "Unknown")
    end
end

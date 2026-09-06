require "socket"

class FakeFeedServer
  class << self
    def current
      @current ||= new
    end
  end

  attr_reader :port
  attr_accessor :routes

  def initialize
    @lock = Mutex.new
    @routes = {}
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def origin
    "http://127.0.0.1:#{port}"
  end

  def url_for(path)
    "#{origin}#{path}"
  end

  def serve_body(path, body, content_type: "application/xml", headers: {})
    @lock.synchronize do
      @routes[path] = { status: "200 OK", body: body, type: content_type, headers: headers }
    end
    url_for(path)
  end

  def serve_redirect(path, location)
    @lock.synchronize { @routes[path] = { status: "302 Found", location: location, body: "" } }
    url_for(path)
  end

  def reset!
    @lock.synchronize { @routes.clear }
  end

  def rss(items)
    entries = items.map do |item|
      <<~ITEM
        <item>
          <title>#{item[:title]}</title>
          <link>#{item[:link]}</link>
          <guid isPermaLink="false">#{item[:id]}</guid>
          <pubDate>#{item.fetch(:published, 'Mon, 30 Aug 2027 12:00:00 GMT')}</pubDate>
          <description>#{item[:description]}</description>
        </item>
      ITEM
    end.join

    <<~FEED
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0"><channel>
      <title>A feed</title>
      #{entries}
      </channel></rss>
    FEED
  end

  def atom(items)
    entries = items.map do |item|
      <<~ENTRY
        <entry>
          <title>#{item[:title]}</title>
          <link href="#{item[:link]}"/>
          <id>#{item[:id]}</id>
          <updated>#{item.fetch(:published, '2027-08-30T12:00:00Z')}</updated>
          <summary>#{item[:description]}</summary>
        </entry>
      ENTRY
    end.join

    <<~FEED
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
      <title>A feed</title>
      #{entries}
      </feed>
    FEED
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
      while (header = socket.gets) && header.strip != ""
      end

      path = request.split(" ")[1].to_s
      route = @lock.synchronize { @routes[path] }

      socket.print(route ? rendered(route) : missing)
    rescue Errno::EPIPE, IOError
      nil
    ensure
      socket.close rescue nil
    end

    def rendered(route)
      headers = [
        "HTTP/1.1 #{route[:status]}",
        "Content-Type: #{route[:type] || 'text/plain'}",
        "Content-Length: #{route[:body].bytesize}"
      ]
      headers << "Location: #{route[:location]}" if route[:location]
      route[:headers].to_h.each { |name, value| headers << "#{name}: #{value}" }

      (headers + [ "Connection: close", "", route[:body] ]).join("\r\n")
    end

    def missing
      [ "HTTP/1.1 404 Not Found", "Content-Length: 0", "Connection: close", "", "" ].join("\r\n")
    end
end

require "socket"

class FakeImapServer
  Message = Struct.new(:uid, :source, :flags, keyword_init: true)

  class << self
    def current
      @current ||= new
    end
  end

  attr_reader :port, :fetched

  def initialize
    @lock = Mutex.new
    @fetched = []
    @mailboxes = Hash.new { |all, name| all[name] = { uidvalidity: 1, uidnext: 1, messages: [] } }
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def host
    "127.0.0.1"
  end

  def deliver(mailbox: "INBOX", from: "Someone <someone@localhost>", subject:, body:)
    source = <<~MAIL.gsub("\n", "\r\n")
      From: #{from}
      To: someone-else@localhost
      Subject: #{subject}
      Date: #{Time.now.rfc2822}
      Message-ID: <#{SecureRandom.hex(8)}@localhost>
      Content-Type: text/plain; charset=UTF-8

      #{body}
    MAIL

    @lock.synchronize do
      box = @mailboxes[mailbox]
      uid = box[:uidnext]
      box[:uidnext] += 1
      box[:messages] << Message.new(uid: uid, source: source, flags: [])
      uid
    end
  end

  def renumber!(mailbox: "INBOX")
    @lock.synchronize do
      box = @mailboxes[mailbox]
      box[:uidvalidity] += 1
      box[:uidnext] = 1
      box[:messages].each_with_index { |message, index| message.uid = index + 1 }
      box[:uidvalidity]
    end
  end

  def uidvalidity(mailbox: "INBOX")
    @lock.synchronize { @mailboxes[mailbox][:uidvalidity] }
  end

  def flags(mailbox: "INBOX")
    @lock.synchronize { @mailboxes[mailbox][:messages].map { |message| message.flags.dup } }
  end

  def reset!
    @lock.synchronize do
      @mailboxes.clear
      @fetched.clear
    end
  end

  private

    def serve
      loop do
        socket = @server.accept
        Thread.new { converse(socket) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def converse(socket)
      socket.print "* OK [CAPABILITY IMAP4REV1 AUTH=PLAIN] fake ready\r\n"
      selected = nil

      while (line = socket.gets)
        tag, command, rest = line.chomp.split(" ", 3)
        next if tag.nil?

        case command.to_s.upcase
        when "CAPABILITY"
          socket.print "* CAPABILITY IMAP4REV1 AUTH=PLAIN\r\n#{tag} OK done\r\n"
        when "LOGIN"
          socket.print "#{tag} OK signed in\r\n"
        when "EXAMINE", "SELECT"
          selected = unquote(rest.to_s.strip)
          socket.print examine(selected) + "#{tag} OK [READ-ONLY] selected\r\n"
        when "UID"
          socket.print uid_command(selected, rest.to_s) + "#{tag} OK done\r\n"
        when "LOGOUT"
          socket.print "* BYE\r\n#{tag} OK signed out\r\n"
          break
        when "NOOP"
          socket.print "#{tag} OK done\r\n"
        else
          socket.print "#{tag} BAD #{command}\r\n"
        end
      end
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      nil
    ensure
      socket.close rescue nil
    end

    def examine(name)
      box = @lock.synchronize { @mailboxes[name] }

      [
        "* #{box[:messages].size} EXISTS",
        "* 0 RECENT",
        "* OK [UIDVALIDITY #{box[:uidvalidity]}] generation",
        "* OK [UIDNEXT #{box[:uidnext]}] next"
      ].join("\r\n") + "\r\n"
    end

    def uid_command(name, rest)
      verb, arguments = rest.split(" ", 2)

      case verb.to_s.upcase
      when "SEARCH" then uid_search(name, arguments.to_s)
      when "FETCH" then uid_fetch(name, arguments.to_s)
      else ""
      end
    end

    def uid_search(name, arguments)
      messages = @lock.synchronize { @mailboxes[name][:messages].dup }
      found = if arguments.strip.upcase.start_with?("UID")
        low = arguments[/(\d+):/, 1].to_i
        messages.select { |message| message.uid >= low }
      else
        messages
      end

      "* SEARCH #{found.map(&:uid).join(' ')}\r\n"
    end

    def uid_fetch(name, arguments)
      wanted = sequence(arguments[/\A([\d,:]+)/, 1].to_s)
      peek = arguments.include?("BODY.PEEK")
      whole = arguments.include?("BODY")
      @fetched << arguments
      partial = arguments[/BODY\.PEEK\[\]<(\d+)\.(\d+)>/] && [ $1.to_i, $2.to_i ]

      @lock.synchronize do
        box = @mailboxes[name]

        box[:messages].select { |message| wanted.include?(message.uid) }.map do |message|
          message.flags |= [ "\\Seen" ] if whole && !peek

          sequence = box[:messages].index(message) + 1
          "* #{sequence} FETCH #{attributes(message, whole, partial)}\r\n"
        end.join
      end
    end

    def sequence(text)
      text.split(",").flat_map do |part|
        low, high = part.split(":")
        high ? (low.to_i..high.to_i).to_a : [ low.to_i ]
      end
    end

    def attributes(message, whole, partial = nil)
      parts = [ "UID #{message.uid}", "RFC822.SIZE #{message.source.bytesize}" ]
      parts << "FLAGS (#{message.flags.join(' ')})"
      parts << envelope(message)

      if partial
        served = message.source.byteslice(partial.first, partial.last).to_s
        parts << "BODY[]<#{partial.first}> {#{served.bytesize}}\r\n#{served}"
      elsif whole
        parts << "BODY[] {#{message.source.bytesize}}\r\n#{message.source}"
      end

      "(#{parts.join(' ')})"
    end

    def envelope(message)
      mail = Mail.read_from_string(message.source)
      from = addresses(mail.from_addrs)
      to = addresses(mail.to_addrs)

      [
        "ENVELOPE (",
        quote(mail.date&.rfc2822), " ",
        quote(mail.subject), " ",
        from, " ", from, " ", from, " ", to,
        " NIL NIL NIL ",
        quote(mail.message_id && "<#{mail.message_id}>"),
        ")"
      ].join
    end

    def addresses(list)
      return "NIL" if list.blank?

      inner = Array(list).map do |raw|
        local, host = raw.to_s.split("@", 2)
        "(NIL NIL #{quote(local)} #{quote(host)})"
      end.join

      "(#{inner})"
    end

    def quote(value)
      value.nil? ? "NIL" : "\"#{value.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
    end

    def unquote(value)
      value.to_s.delete_prefix('"').delete_suffix('"')
    end
end

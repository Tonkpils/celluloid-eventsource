require 'webrick'
require 'atomic'
require 'json'

require 'support/black_hole'

class DummyServer < WEBrick::HTTPServer
  CHUNK_SIZE = 100
  CONFIG = {
      :BindAddress  => '127.0.0.1',
      :Port         => 5000,
      :AccessLog    => BlackHole,
      :Logger       => BlackHole,
      :DoNotListen  => true,
      :OutputBufferSize => CHUNK_SIZE
  }.freeze

  def initialize(options = {})
    super(CONFIG)
    mount('/', SSETestServlet)
    mount('/error', ErrorServlet)
  end

  def endpoint
    "#{scheme}://#{addr}:#{port}"
  end

  def addr
    config[:BindAddress]
  end

  def port
    config[:Port]
  end

  def scheme
    'http'
  end

  # Simple server that broadcasts Time.now
  class SSETestServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(*args)
      @event_id = Atomic.new(0)
      super
    end

    def do_GET(req, res)
      event = String(Array(req.path.match(/\/?(\w+)/i)).pop).to_sym
      res.content_type = 'text/event-stream; charset=utf-8'
      res['Cache-Control'] = 'no-cache'
      r,w = IO.pipe
      res.body = r
      res.chunked = true
      t = Thread.new do
        begin
          w << "retry: 1000\n"
          case event
          when :continuous_chunks
            data = "data: %s\ndata: %s\ndata: %s\n\n" % ["o" * CHUNK_SIZE, "m" * CHUNK_SIZE, "g" * CHUNK_SIZE]
            w << data
          when :multiple_chunks
            data = {test: "long_chunk", another_chunk: "a" * CHUNK_SIZE, chunks: "f" * CHUNK_SIZE}.to_json
            w << "data: #{data}\n\n"
          when :continuous
            w << "data: YHOO\ndata: +2\ndata: 10\n\n"
          when :chunk
            data = "f" * (CHUNK_SIZE + 25)
            w << "data: %s\n\n" % data
          when :ping
            w << ": ignore this line\n"
            w << "event: \ndata: pong\n\n"  # easy way to know a 'ping' has been sent
          else
            42.times do
              w << "id: %s\nevent: %s\ndata: %s\n\n" % [ @event_id.update { |v| v + 1 },
                                                         event,
                                                         Time.now ]
            end
            w << "event: %s\ndata: %s\n\n" % %w(end end)
          end
        rescue => ex
          puts $!.inspect, $@ unless ex.is_a?(Errno::EPIPE)
        ensure
          w.close
        end
      end
    end
  end

  class ErrorServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(req, res)
      res.content_type = 'application/json; charset=utf-8'
      res.status = 400
      res.keep_alive = false  # true by default
      res.body = '{"msg": "blop"}'
    end
  end
end



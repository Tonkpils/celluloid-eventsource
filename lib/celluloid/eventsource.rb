require "celluloid/eventsource/version"
require 'celluloid/io'
require 'celluloid/eventsource/response_parser'

module Celluloid
  class EventSource
    include  Celluloid::IO

    attr_reader :url, :with_credentials

    CONNECTING = 0
    OPEN = 1
    CLOSED = 2

    attr_reader :ready_state

    def initialize(url, options = {})
      options = options.dup
      @url = URI.parse(url)
      @ready_state = CONNECTING
      @with_credentials = options.delete(:with_credentials) { false }

      @reconnect_timeout = 10
      @last_event_id = String.new

      @on_open = ->() {}
      @on_error = ->(message) {}
      @on_message = ->(message) {}

      @socket = Celluloid::IO::TCPSocket.new(@url.host, @url.port)
      @parser = ResponseParser.new

      yield self if block_given?

      async.run
    end

    def connected?
      @ready_state == OPEN
    end

    def run
      establish_connection

      @socket.each do |data|
        @parser << data
        handle_stream(@parser.chunk)
      end
    end

    def establish_connection
      @socket.write(request_string)

      until @parser.headers?
        @parser << @socket.readline
      end

      if @parser.status_code != 200
        close
        @on_error.call("Unable to establish connection. Response status #{@parser.status_code}")
      end

      handle_headers(@parser.headers)
    end

    def close
      @ready_state = CLOSED
      @socket.close
    end

    def on_open(&block)
      @on_open = block
    end

    def on_message(&block)
      @on_message = block
    end

    def on_error(&block)
      @on_error = block
    end

    private

    def handle_stream(stream)
      data = ""

      stream.split("\n").each do |part|
        case part
          when /^data:(.+)$/
            data = $1
          when /^id:(.+)$/
            @last_event_id = $1
          when /^retry:(.+)$/
            @reconnect_timeout = $1.to_i
          when /^event:(.+)$/
            # TODO
        end
      end

      return if data.empty?
      data.chomp!("\n")

      @on_message.call(data)
    end

    def handle_headers(headers)
      if headers['Content-Type'].include?("text/event-stream")
        @ready_state = OPEN
        @on_open.call
      else
        close
        @on_error.call("Invalid Content-Type #{headers['Content-Type']}. Expected text/event-stream")
      end
    end

    def request_string
      "GET #{url.request_uri} HTTP/1.1\r\nHost: #{url.host}\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\n\r\n"
    end

  end

end

require "celluloid/eventsource/version"
require 'celluloid/io'

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

      @socket = Celluloid::IO::TCPSocket.new(@url.host, @url.port)

      yield self if block_given?

      async.run
    end

    def run
      establish_connection

      until @socket.eof?
        puts @socket.readline
      end
    end

    # TODO: Possibly delegate methods to url
    def establish_connection
      @socket.write(request_string)
      @ready_state = OPEN
    end

    def close
      @ready_state = CLOSED
      @socket.close
    end

    def on_open
      # TODO: Handle on open
    end

    def on_message
      # TODO: Handle on message
    end

    def on_close
      # TODO: Handle on close
    end

    private

    def request_string
      "GET #{url.request_uri} HTTP/1.1\r\nHost: #{url.host}\r\nAccept: text/event-stream\r\n\r\n"
    end
  end

end

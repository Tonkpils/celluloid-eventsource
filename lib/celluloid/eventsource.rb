require "celluloid/eventsource/version"
require 'celluloid/io'
require 'celluloid/eventsource/response_parser'
require 'uri'

module Celluloid
  class EventSource
    include Celluloid::IO

    attr_reader :url, :with_credentials
    attr_reader :ready_state

    CONNECTING = 0
    OPEN = 1
    CLOSED = 2

    execute_block_on_receiver :initialize

    def initialize(uri, options = {})
      self.url = uri
      options  = options.dup
      @ready_state = CONNECTING
      @with_credentials = options.delete(:with_credentials) { false }
      @headers = default_request_headers.merge(options.fetch(:headers, {}))

      @event_type_buffer = ""
      @last_event_id_buffer = ""
      @data_buffer = ""

      @last_event_id = String.new

      @reconnect_timeout = 10
      @on = { open: ->{}, message: ->(_) {}, error: ->(_) {} }
      @parser = ResponseParser.new

      yield self if block_given?

      async.listen
    end

    def url=(uri)
      @url = URI(uri)
    end

    def connected?
      ready_state == OPEN
    end

    def closed?
      ready_state == CLOSED
    end

    def listen
      establish_connection

      process_stream
    rescue IOError
      # Closing the socket during read causes this exception and kills the actor
      # We really don't wan to do anything if the socket is closed.
    end

    def close
      @socket.close if @socket
      @ready_state = CLOSED
    end

    def on(event_name, &action)
      @on[event_name.to_sym] = action
    end

    def on_open(&action)
      @on[:open] = action
    end

    def on_message(&action)
      @on[:message] = action
    end

    def on_error(&action)
      @on[:error] = action
    end

    private

    def ssl?
      url.scheme == 'https'
    end

    def establish_connection
      @socket = Celluloid::IO::TCPSocket.new(@url.host, @url.port)

      if ssl?
        @socket = Celluloid::IO::SSLSocket.new(@socket)
        @socket.connect
      end

      @socket.write(request_string)

      until @parser.headers?
        @parser << @socket.readline
      end

      if @parser.status_code != 200
        until @socket.eof?
          @parser << @socket.readline
        end
        close
        @on[:error].call({status_code: @parser.status_code, body: @parser.chunk})
      end

      handle_headers(@parser.headers)
    end

    def default_request_headers
      {
        'Accept'        => 'text/event-stream',
        'Cache-Control' => 'no-cache',
        'Host'          => url.host
      }
    end

    def process_field(line)
      case line
      when /^data:(.+)$/
        @data_buffer << $1.lstrip.concat("\n")
      when /^id:(.+)$/
        @last_event_id_buffer = $1.lstrip
      when /^retry:(\d+)$/
        @reconnect_timeout = $1.to_i
      when /^event:(.+)$/
        @event_type_buffer = $1.lstrip
      end
    end

    MessageEvent = Struct.new(:type, :data, :last_event_id)

    def process_event
      @last_event_id = @last_event_id_buffer

      unless @data_buffer.empty?
        @data_buffer = @data_buffer.chomp("\n") if @data_buffer.end_with?("\n")
        event = MessageEvent.new(:message, @data_buffer, @last_event_id)
        event.type = @event_type_buffer.to_sym unless @event_type_buffer.empty?

        dispatch_event(event)
      end

      clear_buffers!
    end

    def clear_buffers!
      @data_buffer = ""
      @event_type_buffer = ""
    end

    def dispatch_event(event)
      unless closed?
        @on[event.type] && @on[event.type].call(event)
      end
    end

    def process_stream
      until closed? || @socket.eof?
        line = @socket.readline

        if line.strip.empty?
          process_event
        else
          process_field(line)
        end
      end
    end

    def handle_headers(headers)
      if headers['Content-Type'].include?("text/event-stream")
        @ready_state = OPEN
        @on[:open].call
      else
        close
        @on[:error].call({status_code: @parser.status_code, body: "Invalid Content-Type #{headers['Content-Type']}. Expected text/event-stream"})
      end
    end

    def request_string
      headers = @headers.map { |k, v| "#{k}: #{v}" }

      ["GET #{url.request_uri} HTTP/1.1", headers].flatten.join("\r\n").concat("\r\n\r\n")
    end

  end

end

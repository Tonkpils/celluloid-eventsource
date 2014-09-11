require 'rubygems'
require 'bundler/setup'

require 'celluloid/eventsource'
require 'celluloid/rspec'

require 'reel'

logfile = File.open(File.expand_path("../../log/test.log", __FILE__), 'a')
logfile.sync = true

Celluloid.logger = Logger.new(logfile)

RSpec.configure do |config|
  config.expose_dsl_globally = false
end

class ServerSentEvents < Reel::Server::HTTP
  include Celluloid::Logger

  attr_reader :last_event_id, :connections

  def initialize(ip = '127.0.0.1', port = 63310)
    @connections = []
    @history = []
    @last_event_id = 0
    super(ip, port, &method(:on_connection))
  end

  def broadcast(event, data)
    if @history.size >= 10
      @history.slice!(0, @history.size - 1000)
    end

    @last_event_id += 1
    @history << { id: @last_event_id, event: event, data: data }

    @connections.each do |socket|
      async.send_sse(socket, data, event, @last_event_id)
    end
    true
  end

  def send_ping
    @connections.each do |socket|
      begin
        socket << ":\n"
      rescue Reel::SocketError
        @connections.delete(socket)
      end
    end
  end

  private
    # event and id are optional, Eventsource only needs data
    def send_sse(socket, data, event = nil, id = nil)
      begin
        socket.id id if id
        socket.event event if event
        socket.data data
      rescue Reel::SocketError, NoMethodError
        @connections.delete(socket) if @connections.include?(socket)
      end
    end

  def handle_request(request)
    event_stream = Reel::EventStream.new do |socket|
      @connections << socket
      socket.retry 5000
      # after a Connection reset resend newer Messages to the Client, query['last_event_id'] is needed for https://github.com/Yaffle/EventSource
      if @history.count > 0 && id = request.headers['Last-Event-ID']
        begin
          if history = @history.select {|h| h[:id] >= Integer(id)}.map {|a| "id: \nevent: %s%s\ndata: %s" % [a[:id], a[:event], a[:data]]}.join("\n\n")
            socket << "%s\n\n" % [history]
          end
        rescue ArgumentError, Reel::SocketError
          @connections.delete(socket)
          request.close
        end
      end
    end

    request.respond Reel::StreamResponse.new(:ok, {
        'Content-Type' => 'text/event-stream; charset=utf-8',
        'Cache-Control' => 'no-cache'}, event_stream)
  end

  def on_connection(connection)
    connection.each_request do |request|
      if request.path == '/error'
        request.respond :bad_request, {'Content-Type' => 'application/json; charset=UTF-8'}, "blop"
        request.close
      elsif request.path == '/error/no_body'
        request.respond :bad_request, {'Content-Type' => 'application/json; charset=UTF-8'}
        request.close
      else
        handle_request(request)
      end
    end
  end
end

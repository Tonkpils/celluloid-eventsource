require 'spec_helper'

TIMEOUT = 0.001

RSpec.describe Celluloid::EventSource do
  let(:data) { "foo bar " }

  def with_sse_server
    server = ServerSentEvents.new
    yield server
  end

  describe '#initialize' do
    let(:ces)  { double(Celluloid::EventSource) }
    let(:url)  { "example.com" }

    it "runs on an ssl socket for https" do
      expect(Celluloid::IO::TCPSocket).to receive(:new).and_return(ces)
      expect(Celluloid::IO::SSLSocket).to receive(:new).with(ces)

      Celluloid::EventSource.new("https://#{url}")
    end


    it 'runs asynchronously' do
      expect_any_instance_of(Celluloid::EventSource).to receive(:async).and_return(ces)
      expect(ces).to receive(:listen)

      Celluloid::EventSource.new("http://#{url}")
    end

    it 'allows customizing headers' do
      auth_header = { "Authorization" => "Basic aGVsbG86dzBybGQh" }

      es = Celluloid::EventSource.new("http://#{url}", :headers => auth_header)

      headers = es.instance_variable_get('@headers')
      expect(headers['Authorization']).to eq(auth_header["Authorization"])
    end
  end

  it "keeps track of last event id" do
    with_sse_server do |server|
      ces = Celluloid::EventSource.new("http://localhost:63310") do |conn|
        conn.on_message { |message| message }
      end

      sleep TIMEOUT until ces.connected?

      expect { server.broadcast(nil, data) }.to change { ces.last_event_id }.to("1")
    end
  end

  it "ignores comment ':' lines" do
    with_sse_server do |server|
      expect { |event|
        ces = Celluloid::EventSource.new("http://localhost:63310") do |conn|
          conn.on_message(&event)
        end

        sleep TIMEOUT until ces.connected?

        server.send_ping

        sleep TIMEOUT
      }.to_not yield_control
    end
  end

  it 'receives data through message event' do
    with_sse_server do |server|
      expect { |event|
        ces = Celluloid::EventSource.new("http://localhost:63310") do |conn|
          conn.on_message(&event)
        end

        sleep TIMEOUT until ces.connected?

        server.broadcast(nil, data)

        sleep TIMEOUT
      }.to yield_with_args(data)
    end
  end


  it 'receives custom events through event handlers' do
    with_sse_server do |server|
      event_name     = :custom_event

      expect { |event|
        ces = Celluloid::EventSource.new("http://localhost:63310") do |conn|
          conn.on(event_name, &event)
        end

        sleep TIMEOUT until ces.connected?

        server.broadcast(event_name, data)

        sleep TIMEOUT
      }.to yield_with_args(data)
    end
  end

end

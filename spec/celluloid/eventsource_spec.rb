require 'spec_helper'
require 'support/dummy_server'


# See: https://html.spec.whatwg.org/multipage/comms.html#event-stream-interpretation
RSpec.describe Celluloid::EventSource do

  run_server(:dummy) { DummyServer.new }

  describe '#initialize' do
    let(:url)  { "example.com" }

    it 'runs asynchronously' do
      ces = double(Celluloid::EventSource)
      expect_any_instance_of(Celluloid::EventSource).to receive_message_chain(:async, :listen).and_return(ces)

      Celluloid::EventSource.new("http://#{url}")
    end

    it 'allows customizing headers' do
      auth_header = { "Authorization" => "Basic aGVsbG86dzBybGQh" }

      allow_any_instance_of(Celluloid::EventSource).to receive_message_chain(:async, :listen)
      es = Celluloid::EventSource.new("http://#{url}", :headers => auth_header)

      headers = es.instance_variable_get('@headers')
      expect(headers['Authorization']).to eq(auth_header["Authorization"])
    end
  end

  context 'callbacks' do

    let(:future) { Celluloid::Future.new }
    let(:value_class) { Class.new(Struct.new(:value)) }

    describe '#on_open' do

      it 'the client has an opened connection' do

        Celluloid::EventSource.new(dummy.endpoint) do |conn|
          conn.on_open do
            future.signal(value_class.new({ called: true, state: conn.ready_state }))
            conn.close
          end
        end

        expect(future.value).to eq({ called: true, state: Celluloid::EventSource::OPEN })
      end
    end

    describe '#on_error' do

      it 'receives response body through error event' do

        Celluloid::EventSource.new("#{dummy.endpoint}/error") do |conn|
          conn.on_error do |error|
            future.signal(value_class.new({ msg: error, state: conn.ready_state }))
          end
        end

        expect(future.value).to eq({ msg: { status_code: 400, body: '{"msg": "blop"}' },
                                     state: Celluloid::EventSource::CLOSED })
      end
    end

    describe '#on_message' do

      it 'receives data through message event' do

        Celluloid::EventSource.new(dummy.endpoint) do |conn|
          conn.on_message do |message|
            if '3' == message.last_event_id
              future.signal(value_class.new({ msg: message, state: conn.ready_state }))
              conn.close
            end
          end
        end

        payload = future.value
        expect(payload[:msg]).to be_a(Celluloid::EventSource::MessageEvent)
        expect(payload[:msg].type).to eq(:message)
        expect(payload[:msg].last_event_id).to eq('3')
        expect(payload[:state]).to eq(Celluloid::EventSource::OPEN)
      end

      it 'ignores lines starting with ":"' do

        Celluloid::EventSource.new("#{dummy.endpoint}/ping") do |conn|
          conn.on_message do |message|
            future.signal(value_class.new({ msg: message, state: conn.ready_state }))
            conn.close
          end
        end

        expect(future.value[:msg].data).to eq('pong')

      end
    end

    describe '#on' do
      let(:custom) { :custom_event }

      it 'receives custom events and handles them' do

        Celluloid::EventSource.new("#{dummy.endpoint}/#{custom}") do |conn|
          conn.on(custom) do |message|
            future.signal(value_class.new({ msg: message, state: conn.ready_state }))
            conn.close
          end
        end

        payload = future.value
        expect(payload[:msg]).to be_a(Celluloid::EventSource::MessageEvent)
        expect(payload[:msg].type).to eq(custom)
        expect(payload[:msg].last_event_id).to eq('1')
        expect(payload[:state]).to eq(Celluloid::EventSource::OPEN)
      end
    end
  end
end

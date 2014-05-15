require 'spec_helper'

describe Celluloid::EventSource do
  let(:ces) {double(Celluloid::EventSource)}

  before :each do
    Celluloid::IO::TCPSocket.stub(:new).with('example.com', 80)
  end

  describe '#initialize' do
    before :each do
      Celluloid::EventSource.any_instance.should_receive(:async).and_return(ces)
      ces.should_receive(:listen)
    end

    it 'runs asynchronously on initialize' do
      Celluloid::EventSource.new("http://example.com")
    end

    it 'allows customizing headers' do
      es = Celluloid::EventSource.new('http://example.com', :headers => {'Authorization' => 'Basic aGVsbG86dzBybGQh'})

      headers = es.instance_variable_get('@headers')
      expect(headers['Authorization']).to_not be_nil
    end
  end
end

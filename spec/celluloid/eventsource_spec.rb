require 'spec_helper'

describe Celluloid::EventSource do

  it 'runs asynchronously on initialize' do
    ces = double(Celluloid::EventSource)
    Celluloid::IO::TCPSocket.stub(:new).with("example.com", 80)
    Celluloid::EventSource.any_instance.should_receive(:async).and_return(ces)
    ces.should_receive(:run)

    Celluloid::EventSource.new("http://example.com")
  end
end
require 'spec_helper'

RSpec.describe Celluloid::EventSource::ResponseParser do

  let(:success_headers) {<<-eos
HTTP/1.1 200 OK
Last-Modified: Wed, 08 Jan 2003 23:11:55 GMT
Content-Type: text/html; charset=UTF-8
Content-Length: 131
X_CASE_HEADER: foo
X_Mixed-Case: bar
eos
}

  let(:error_headers) {<<-eos
HTTP/1.1 400 OK
Last-Modified: Wed, 08 Jan 2003 23:11:55 GMT
Content-Type: text/html; charset=UTF-8
Content-Length: 131
eos
}

  let(:response_string) { "#{success_headers}\n\n{'hello' : 'world'}\n"}

  let(:parser) { subject }


  def streamed(string)
    stream = StringIO.new(string)
    stream.each do |line|
      yield line
    end
  end

  it 'parses a complete http response' do
    streamed(response_string) do |line|
      parser << line
    end

    expect(parser.status).to eq(200)
    expect(parser.headers?).to be_truthy
    expect(parser.headers['Content-Type']).to eq('text/html; charset=UTF-8')
    expect(parser.headers['Content-Length']).to eq("131")
  end

  it 'waits until the entire request is found' do
    streamed(success_headers) do |line|
      parser << line
    end

    expect(parser.status).to eq(200)
    expect(parser.headers?).to be_falsey
    expect(parser.headers).to be_nil
  end

  it 'makes response headers canonicalized' do
    streamed(response_string) { |line| parser << line }
    expected_headers = {
      'X-Mixed-Case' => 'bar', 'Content-Type' => 'text/html; charset=UTF-8', 'Content-Length' => "131", 'X-Case-Header' => 'foo'
    }
    expect(parser.headers).to include(expected_headers)
  end

end

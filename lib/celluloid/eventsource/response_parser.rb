require 'http/parser'

module Celluloid

  class EventSource

    class ResponseParser
      extend Forwardable

      attr_reader :headers

      delegate [:status_code, :<<] => :@parser

      def initialize
        @parser = Http::Parser.new(self)
        @headers = nil
        @chunk = ""
      end

      def headers?
        !!@headers
      end

      def status
        @parser.status_code
      end

      def on_headers_complete(headers)
        @headers = headers
      end

      def on_body(chunk)
        @chunk << chunk
      end

      def chunk
        chunk = @chunk
        unless chunk.empty?
          @chunk = ""
        end

        chunk.to_s
      end

    end

  end

end
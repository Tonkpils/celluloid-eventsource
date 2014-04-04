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
        @headers = canonical_headers(headers)
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

      private

      def canonical_headers(headers)
        headers.each_with_object({}) do |(key, value), canonicalized_headers|
          name = canonicalize_header(key)
          canonicalized_headers[name] = value
        end
      end

      def canonicalize_header(name)
        name.gsub('_', '-').split("-").map(&:capitalize).join("-")
      end
    end

  end

end

# Celluloid::Eventsource

An EventSource client based off Celluloid::IO.

Specification based on EventSourcehttp://www.w3.org/TR/2012/CR-eventsource-20121211/

## Installation

Add this line to your application's Gemfile:

    gem 'celluloid-eventsource'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install celluloid-eventsource

and `require 'celluloid/eventsource'`.

## Usage

Initializing a new `Celluloid::EventSource` object will create the connection:

```ruby
es = Celluloid::EventSource.new("http://example.com/")
```

Messages can be received on events such as `on_open`, `on_message` and `on_error`.

These can be assigned at initialize time

```ruby
es = Celluloid::EventSource.new("http://example.com/") do |conn|
  conn.on_message do |message|
    puts "Message: #{message}"
  end
end
```

or on the object itself.

```ruby
es.on_message do |message|
  puts "Message: #{message}"
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

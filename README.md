# Celluloid::Eventsource

[![Gem Version](https://badge.fury.io/rb/celluloid-eventsource.png)](http://badge.fury.io/rb/celluloid-eventsource)

#### Under Development!! Use at your own risk :)

An EventSource client based off Celluloid::IO.

Specification based on [EventSource](http://www.w3.org/TR/2012/CR-eventsource-20121211/)

## Installation

Add this line to your application's Gemfile:

    gem 'celluloid-eventsource'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install celluloid-eventsource

then somewhere in your project:

    require 'celluloid/eventsource'

## Usage

Initializing a new `Celluloid::EventSource` object will create the connection:

```ruby
es = Celluloid::EventSource.new("http://example.com/")
```

Messages can be received on events such as `on_open`, `on_message` and `on_error`.

These can be assigned at initialize time

```ruby
es = Celluloid::EventSource.new("http://example.com/") do |conn|
  conn.on_open do 
    puts "Connection was made"
  end
  
  conn.on_message do |message|
    puts "Message: #{message}"
  end
  
  conn.on_error do |message|
    puts "Error message #{message}"
  end
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


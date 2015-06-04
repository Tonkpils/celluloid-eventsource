require 'rubygems'
require 'bundler/setup'

require 'celluloid/eventsource'
require 'celluloid/rspec'

logfile = File.open(File.expand_path("../../log/test.log", __FILE__), 'a')
logfile.sync = true

Celluloid.logger = Logger.new(logfile)

RSpec.configure do |config|
  config.expose_dsl_globally = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random
end

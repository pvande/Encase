unless ENV['CI']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
    add_group "Decorator", 'decorator.rb'
    add_group "Contracts", 'contracts?.rb'
  end
end

RSpec.configure do |conf|
  conf.after(:suite) do
    puts "\n"
    SimpleCov.at_exit.call
  end unless ENV['CI']
end

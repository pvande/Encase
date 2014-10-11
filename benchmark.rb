$LOAD_PATH << File.dirname(__FILE__) + '/lib'

require 'benchmark/ips'
require 'encase'

class Simple
  def self.fib(n)
    return n if n < 2
    return fib(n - 1) + fib(n - 2)
  end
end

class Checked
  def self.fib(n)
    raise 'Exception!' unless Integer === n
    return result = n if n < 2
    return result = fib(n - 1) + fib(n - 2)
  ensure
    raise 'Exception!' unless Integer === result
  end
end

class Contracted
  include Encase::Contracts

  Contract Integer => Integer
  def self.fib(n)
    return n if n < 2
    return fib(n - 1) + fib(n - 2)
  end
end

Benchmark.ips do |x|
  x.config(:time => 10, :warmup => 2)

  x.report("Unadorned") { Simple.fib(6) }
  x.report("Checked") { Checked.fib(6) }
  x.report("Contracted") { Contracted.fib(6) }

  x.compare!
end

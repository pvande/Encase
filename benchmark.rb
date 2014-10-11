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

module Contracted
  class Unchecked
    include Encase::Contracts

    Contract()
    def self.fib(n)
      return n if n < 2
      return fib(n - 1) + fib(n - 2)
    end
  end

  class ArgumentCheck
    include Encase::Contracts

    Contract Integer
    def self.fib(n)
      return n if n < 2
      return fib(n - 1) + fib(n - 2)
    end
  end

  class ReturnCheck
    include Encase::Contracts

    Contract Encase::Contracts::Returns[Integer]
    def self.fib(n)
      return n if n < 2
      return fib(n - 1) + fib(n - 2)
    end
  end

  class ArgumentAndReturnCheck
    include Encase::Contracts

    Contract Integer => Integer
    def self.fib(n)
      return n if n < 2
      return fib(n - 1) + fib(n - 2)
    end
  end
end

Benchmark.ips do |x|
  x.config(:time => 4, :warmup => 2)

  x.report("Unadorned") { Simple.fib(6) }
  x.report("Checked") { Checked.fib(6) }
  x.report("Contracted: Empty") { Contracted::Unchecked.fib(6) }
  x.report("Contracted: Args") { Contracted::ArgumentCheck.fib(6) }
  x.report("Contracted: Returns") { Contracted::ReturnCheck.fib(6) }
  x.report("Contracted: Both") { Contracted::ArgumentAndReturnCheck.fib(6) }

  x.compare!
end

unless ENV['CI'] or RUBY_VERSION =~ /^1\.8\./
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
    add_group "Decorator", 'decorator.rb'
    add_group "Contracts", 'contracts?.rb'
  end
end

RSpec.configure do |conf|
  if require 'benchmark'
    conf.after :suite do
      puts "\n"

      class BenchmarkingTest
        def undecorated_method(x, y, z)
          [x, y, z]
        end

        include Encase::Decorator.module
        Decorator()
        def with_decorator(x, y, z)
          [x, y, z]
        end

        include Encase::Contracts
        Contract Symbol, String, Fixnum => [ Symbol, String, Fixnum ]
        def with_contract(x, y, z)
          [x, y, z]
        end
      end

      instance, n = BenchmarkingTest.new, 50_000
      {
        :Validated => proc { },
        :Disabled => proc { Encase::Decorator.disable },
      }.each do |name, code|
        puts "\n#{name}" ; code.call()

        Benchmark.bm(15) do |x|
          x.report('undecorated:') do
            n.times { instance.undecorated_method(:one, '2', 3) }
          end

          x.report('with decorator:') do
            n.times { instance.with_decorator(:one, '2', 3) }
          end

          x.report('with contract:') do
            n.times { instance.with_contract(:one, '2', 3) }
          end
        end
      end
    end
  end

  conf.after(:suite) do
    puts "\n"
    SimpleCov.at_exit.call
  end unless ENV['CI'] or RUBY_VERSION =~ /^1\.8\./
end

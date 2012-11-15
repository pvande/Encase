require 'encase/decorator'
require 'encase/contracts'

module Encase
  class Match < Decorator
    @@methods = Hash.new { |h,k| h[k] = {} }
    @@contracts = Hash.new { |h,k| h[k] = [] }

    def initialize(contract)
      @contract = contract
      def contract.success(*); true; end
      def contract.failure(*); false; end

      contracts, methods = @@contracts, @@methods
      (class << contract; self; end).send(:define_method, :around) do |code, args, block|
        b = [block]
        matched = contracts[[decorated_class, decorated_method]].find do |c|
          (c.constraints.key?(:args) ? c.validate(c.constraints[:args], args) : true) &&
          (c.constraints.key?(:block) ? c.validate([c.constraints[:block]], b=[block]) : true)
        end
        block = b.first

        raise 'hell' unless matched

        callable = methods[[decorated_class, decorated_method]][matched]
        callable = callable.bind(binding) if callable.respond_to?(:bind)
        callable.call(*args, &block)
      end
    end

    def wrap_callable(code)
      @@contracts[[decorated_class, decorated_method]] << @contract
      @@methods[[decorated_class, decorated_method]][@contract] = code
      return code
    end
  end
end

module Encase::PatternMatching
  # @implicit
  # Including this module will include the `Contract` decorator method.
  # @param base [Class] the class including this module
  def self.included(base)
    base.send(:include, Encase::Contract.module)
    base.send(:include, Encase::Match.module)
  end
end

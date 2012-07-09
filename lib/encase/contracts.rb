require 'encase/contract'

# Contracts are a way to simply describe (and enforce) expectations around how
# your code is intended to be used by expressing the type and structure of
# your methods inputs and outputs.  There is a common parallel here with
# statically-checked type systems – both provide guarantees about how data
# flows across method boundaries.
#
# @example A Basic Contract
#   Contract Fixnum, Fixnum => Fixnum
#   def sum_and_triple(a, b)
#     (a + b) * 3
#   end
#
# One advantage to resolving these constraints at runtime is that it allows
# you to leverage the full expressiveness of the host language when describing
# your method's contract.  In fact, these contracts are using Ruby's case
# equality operator to validate constraints, so leveraging your existing code
# is simple, and writing new constraint types is easy.
#
# @example Dynamic Contracts
#   Contract /^\d{1,3}$/ => (0...1000)
#   def parse_number(str)
#     str.to_i(10)
#   end
#
# @example Custom Constraints
#   class Wacky
#     def initialize(range)
#       @range = range
#     end
#     def ===(o)
#       o.respond_to?(:wackiness) && @range.include?(o.wackiness)
#     end
#   end
#
#   Contract Wacky(3..9000) => Wacky(0...1)
#   def dewackify(object)
#     object.wackiness.times { object.calm_down }
#   end
module Encase::Contracts
  # Including this module will include the +Contract+ decorator method.
  # @param base [Class] the class including this module
  # @implicit
  def self.included(base)
    base.send(:include, Encase::Contract.module)
  end
end

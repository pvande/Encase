require 'encase/contract'

# Contracts are a way to simply describe (and enforce) expectations around how
# your code is intended to be used by expressing the type and structure of
# your methods inputs and outputs.  There is a common parallel here with
# statically-checked type systems – both provide guarantees about how data
# flows across method boundaries.
#
#     Contract Fixnum, Fixnum => Fixnum
#     def sum_and_triple(a, b)
#       (a + b) * 3
#     end
#
# One advantage to resolving these constraints at runtime is that it allows
# you to leverage the full expressiveness of the host language when describing
# your method's contract.
#
#     Contract /^\d{1,3}$/ => (0...1000)
#     def parse_number(str)
#       str.to_i(10)
#     end
#
# In fact, these contracts are using Ruby's case equality operator to validate
# constraints, so leveraging your existing code is simple, and writing new
# constraint types is easy.
#
#     class Wacky
#       def initialize(range)
#         @range = range
#       end
#
#       def ===(o)
#         o.respond_to?(:wackiness) && @range.include?(o.wackiness)
#       end
#     end
#
#     Contract Wacky(3..9000) => Wacky(0...1)
#     def dewackify(object)
#       object.wackiness.times { object.calm_down }
#     end
#
# For convenience, there are also a number of meta-typeclasses included in
# this library.
#
# Signature Constraints
# =====================
#
# * <h2>`Splat[<Type>]`</h2>
# {include:Contracts::Splat}
# * <h2>`Returns[<Type>]`</h2>
# {include:Contracts::Returns}
module Encase::Contracts

  # A {Splat} stands in for zero or more positional arguments, just as the
  # Ruby `*args` construct does, allowing you to write constraints for
  # open-ended method signatures.
  #
  #     Contract Splat[Fixnum] => Fixnum
  #     def sum(*numbers)
  #       numbers.inject { |a,b| a + b }
  #     end
  class Splat
    # Creates a new constraint for describing the type of the value returned
    # from the Contracted code.
    # @param type [#===|Array|Hash] the constraint to apply to the arguments
    # @return [Splat<type>] a constraint that validates zero or more arguments
    def self.[](type)
      self.new(type)
    end

    # @implicit
    def initialize(type)
      @type = type
    end

    # Validate that an arguments conforms to the given interface.
    # @param val [#===|Array|Hash] the value to validate
    # @return [Boolean] the result of the validation
    def ===(val)
      @type === val
    end

    # @implicit
    # Provide a recognizable string representation.
    def inspect; "Splat[#{@type.inspect}]"; end
  end

  # This constraint allows you to write a contract for the return value of the
  # method or proc.  Most of the time, you will probably prefer to use the
  # shorthand for this type.
  #
  #     # This describes code that takes a String and returns a String.
  #     Contract String, Returns[String]
  #
  #     # This describes the same thing.
  #     Contract String => String
  #
  # The shorthand is generally considered preferable, but falls short when
  # describing a function that takes no arguments…
  #
  #     # This describes code that takes nil and returns a String!
  #     Contract nil => String
  #
  #     # This describes code that takes an empty list and returns a String!
  #     Contract [] => String
  #
  #     # This describes code that takes no arguments and returns a String.
  #     Contract Returns[String]
  #
  # … and in the case where the last constraint is a Hash containing only a
  # single constraint.
  #
  #     # This describes code that takes a String and a Hash containing the
  #     # keys :path and :name (with a String values).  There is no constraint
  #     # on the returned value.
  #     Contract String, { :path => String, :name => String }
  #
  #     # This describes code that takes both a String and the Symbol :path
  #     # and returns a String!
  #     Contract String, { :path => String }
  #
  #     # This describes code that takes both a String and a Hash containing
  #     # the key :path (with a String value), and returning a String.
  #     Contract String, { :path => String }, Returns[String]
  #
  # This constraint type is only useful as the last argument to `Contract`.
  class Returns < Hash
    # Creates a new constraint for describing the type of the value returned
    # from the Contracted code.
    # @param type [#===|Array|Hash] the constraint for the return value
    # @return [Returns<type>] a constraint that only validates the return value
    def self.[](type)
      super(nil, type)
    end

    # Validate that the return value conforms to the given interface.
    # @param val [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(val)
      values.first === val
    end

    # @implicit
    # Allows us to avoid adding any additional parameter constraints.
    def keys; []; end

    # @implicit
    # Provide a recognizable string representation.
    def inspect; "Returns#{values.inspect}"; end
  end

  # @implicit
  # Including this module will include the `Contract` decorator method.
  # @param base [Class] the class including this module
  def self.included(base)
    base.send(:include, Encase::Contract.module)
  end
end

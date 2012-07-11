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
#     Contract Wacky.new(3..9000) => Wacky.new(0...1)
#     def dewackify(object)
#       object.wackiness.times { object.calm_down }
#     end
#
# For convenience, there are also a number of meta-typeclasses included in
# this library.
#
# Abstract Type Constraints
# =========================
#
# * <h2>`Any`</h2>
# {include:Contracts::Any}
# * <h2>`None`</h2>
# {include:Contracts::None}
#
# Type Constraints
# ================
#
# * <h2>`Code`</h2>
# {include:Contracts::Code}
#
# Signature Constraints
# =====================
#
# * <h2>`Splat[<Type>]`</h2>
# {include:Contracts::Splat}
# * <h2>`Block`</h2>
# {include:Contracts::Block}
# * <h2>`Returns[<Type>]`</h2>
# {include:Contracts::Returns}
module Encase::Contracts

  # The {Any} type is used to validate only the presence of an argument.
  #
  #     Contract Any, Any => Any
  #     def munge(a, b)
  #       a.class.new(b)
  #     end
  class Any

    # Validate that the argument is either a Proc or a Method.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      true
    end

    # @implicit
    # Generates a readable string representation of the constraint.
    # @return [String] a description of this constraint
    def self.to_s
      name.sub(/.*::/, '')
    end
  end

  # The {None} type is used to validate the non-presence of an argument.  Note
  # that this is *not* the same thing as validating the nullness of an
  # argument; for that, use `nil` as your constraint.
  #
  #     Contract None => String
  #     def to_s
  #       self.inspect
  #     end
  #
  #     Contract [None]
  #     def fill_empty_array(array)
  #       array << 1 << 2 << 3
  #     end
  class None

    # Validate that the argument is either a Proc or a Method.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      false
    end

    # @implicit
    # Generates a readable string representation of the constraint.
    # @return [String] a description of this constraint
    def self.to_s
      name.sub(/.*::/, '')
    end
  end

  # The {Code} type represents a first-class executable value, usually a Proc
  # or a bound Method.  More than just a union type, this type will also allow
  # you to describe the expected input and output types of the value, which
  # will be validated when the code is executed.
  #
  #     Contract Symbol => Code
  #     def get_method(name)
  #       self.class.method(name)
  #     end
  #
  #     Contract Code[Object => Fixnum] => Fixnum
  #     def mapping(code)
  #       code.call(self)
  #     end
  class Code

    # Creates a new {Code} constraint describing the expected types of the
    # arguments and return value of the constrained code.
    # @param types [Array[#===|Array|Hash]] the contract constraints to apply
    #        to the code's arguments and return value
    # @return [Code<*types>] a constraint that applies a Contract to the
    #         constrained code value
    def self.[](*types)
      self.new(*types)
    end

    # (see #===)
    # This behaves as if it were an instance created with no arguments.
    def self.===(obj)
      self.new === obj
    end

    # @implicit
    def initialize(*types)
      @types = types
      @contract = Encase::Contract.new(*@types)
      @splatted = types.any? { |t| t.is_a? Splat }
      @arity = types.count { |t| not t.is_a? Splat }
    end

    # Validate that the argument is either a Proc or a Method.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      obj.is_a?(Proc) || obj.is_a?(Method)
    end

    # Passes the callable through to the underlying {Contract} to be wrapped
    # in validation behaviors.
    # @param (see Decorator#wrap_callable)
    # @return (see Decorator#wrap_callable)
    def wrap(callable)
      @contract.wrap_callable(callable)
    end

    # @implicit
    # Generates a readable string representation of the constraint.
    # @return [String] a description of this constraint
    def self.to_s
      name.sub(/.*::/, '')
    end

    # @implicit
    # Generates a readable string representation of the constraint.
    # @return [String] a description of this constraint
    def to_s
      "#{self.class}[#{@contract.to_s.sub(/^Contract( |\(\))/, '')}]"
    end
    alias_method :inspect, :to_s
  end

  # A {Splat} stands in for zero or more positional arguments, just as the
  # Ruby `*args` construct does, allowing you to write constraints for
  # open-ended method signatures.
  #
  #     Contract Splat[Fixnum] => Fixnum
  #     def sum(*numbers)
  #       numbers.inject { |a,b| a + b }
  #     end
  class Splat

    # Creates a new constraint for describing the type of zero or more
    # arguments in a list.
    # @param type [#===|Array|Hash] the constraint to apply to the arguments
    # @return [Splat<type>] a constraint that validates zero or more arguments
    def self.[](type)
      self.new(type)
    end

    # @implicit
    def initialize(type)
      @type = type
    end

    # Validate that the argument conforms to the given interface.
    # @param val [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(val)
      @type === val
    end

    # @implicit
    # Provide a recognizable string representation.
    def to_s; "Splat[#{@type.inspect}]"; end
    alias_method :inspect, :to_s
  end

  # The {Block} constraint functions very much like the {Code} constraint, in
  # that it describes a contract for an executable value.  The distinction is
  # that this type is used specifically to validate the code passed to the
  # {http://bit.ly/P0Rxrw block slot} of the method.
  #
  # This type (like the {Returns} type) is handled specially; you may have
  # only one {Block} in each {Contract}, and it should be the last value
  # before any {Returns}.
  #
  #     Contract Array, Block[Object => Fixnum]
  #     def int_map(array, &block)
  #       array.map(&block)
  #     end
  #
  #     Contract Array, Block[Object => String] => String
  #     def stringify(array, &block)
  #       array.map(&block).join
  #     end
  class Block < Code
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
    # from the constrained code.
    # @param type [#===|Array|Hash] the constraint for the return value
    # @return [Returns<type>] a constraint that validates the return value
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
    def to_s; "Returns#{values.inspect}"; end
    alias_method :inspect, :to_s
  end

  # @implicit
  # Including this module will include the `Contract` decorator method.
  # @param base [Class] the class including this module
  def self.included(base)
    base.send(:include, Encase::Contract.module)
  end
end

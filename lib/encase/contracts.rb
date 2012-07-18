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
# * <h2>`Maybe`</h2>
# {include:Contracts::Maybe}
# * <h2>`None`</h2>
# {include:Contracts::None}
#
# Logical Type Constraints
# ========================
#
# * <h2>`And`</h2>
# {include:Contracts::And}
# * <h2>`Or`</h2>
# {include:Contracts::Or}
# * <h2>`Xor`</h2>
# {include:Contracts::Xor}
# * <h2>`Not`</h2>
# {include:Contracts::Not}
#
# Type Constraints
# ================
#
# * <h2>`Int`</h2>
# {include:Contracts::Int}
# * <h2>`Num`</h2>
# {include:Contracts::Num}
# * <h2>`Bool`</h2>
# {include:Contracts::Bool}
# * <h2>`Code`</h2>
# {include:Contracts::Code}
#
# Dynamic Constraints
# ===================
#
# * <h2>`Test`</h2>
# {include:Contracts::Test}
# * <h2>`Can`</h2>
# {include:Contracts::Can}
# * <h2>`List`</h2>
# {include:Contracts::List}
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

  # @implicit
  # These modules collect common methods, to reduce duplication.
  module Shared
    # @implicit
    module InstanceMethods

      # @implicit
      # Generates a readable string representation of the constraint.
      # @return [String] a description of this constraint
      def to_s
        "#{self.class}[#{@args.map(&:inspect).join(', ')}]"
      end
      alias_method :inspect, :to_s
    end

    # @implicit
    module ClassMethods

      # @implicit
      # Generates a readable string representation of the constraint.
      # @return [String] a description of this constraint
      def to_s
        name.sub(/.*::/, '')
      end
    end

    # @implicit
    module JoinTypeMethods

      # Validate that the argument matches the predicate.
      # @param obj [Object] the value to validate
      # @return [Boolean] the result of the validation
      def ===(obj)
        @types.send(@predicate) { |t| @contract.validate([t], [obj]) }
      end

      # Is this an optional parameter?
      # @return [Bool] returns `true` if all types are optional
      def optional?
        @types.send(@predicate) { |t| t.optional? rescue false }
      end
    end
  end

  # The {Any} type is used to validate only the presence of an argument.
  #
  #     Contract Any, Any => Any
  #     def munge(a, b)
  #       a.class.new(b)
  #     end
  class Any
    self.extend Shared::ClassMethods

    # Validate that the argument is either a Proc or a Method.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      true
    end
  end

  # The {Maybe} type can stand in for a type that might be `nil` or absent.
  #
  #     Contract Maybe[Int] => Maybe[String]
  #     def i_to_s(n)
  #       n.to_s unless n.nil?
  #     end
  class Maybe
    self.send :include, Shared::InstanceMethods
    self.extend Shared::ClassMethods

    # Creates an uncertain type constraint of the supplied type.
    # @param type [#===] the constraint to negate
    # @return [Maybe<type>] a constraint that validates the value, if present
    def self.[](type)
      self.new(type)
    end

    # @implicit
    # (see [])
    def initialize(type)
      @args = [type]
      @type = type
    end

    # Validate that the argument does not exist, or matches the supplied type.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      @type === obj || obj.nil?
    end

    # Is this an optional parameter?
    # @return [Bool] always returns `true`
    def optional?
      true
    end

    # Forward any missing methods to the wrapped type.
    def method_missing(name, *args, &block)
      @type.send(name, *args, &block)
    end

    # @implicit
    # Allow the type to masquerade as its wrapped type.
    # @return [Bool] if the class is an acurate description of the type
    def is_a?(type)
      super or @type.is_a?(type)
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
    self.extend Shared::ClassMethods

    # Validate that the argument is either a Proc or a Method.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      false
    end

    # Is this an optional parameter?
    # @return [Bool] always returns `true`
    def self.optional?
      true
    end
  end

  # The {And} type intersects two or more constraints, validating that the
  # argument is valid for every constraint.
  #
  #     Contract And[Fixnum, (0..5)] => Any
  #     def lookup(n)
  #       array[n]
  #     end
  class And
    self.send :include, Shared::InstanceMethods
    self.send :include, Shared::JoinTypeMethods
    self.extend Shared::ClassMethods

    # Creates a type constraint as an intersection of the supplied types.
    # @param a [#===|Array|Hash] the constraints to intersect
    # @param b [#===|Array|Hash] the constraints to intersect
    # @param rest [Array[#===|Array|Hash]] additional constraints to intersect
    # @return [And<a, b, *rest>] the intersection of the given types
    def self.[](a, b, *rest)
      self.new(a, b, *rest)
    end

    # @implicit
    # (see [])
    def initialize(a, b, *rest)
      @args = @types = [a, b, *rest]
      @predicate = :all?
      class << @contract = Encase::Contract.new
        def success(*); true; end
        def failure(*); false; end
      end
    end
  end

  # The {Or} type unions two or more constraints, validating that the
  # argument is valid for at least one constraint.
  #
  #     Contract Or[String, Fixnum], Or[String, Fixnum] => Or[String, Fixnum]
  #     def plus(a, b)
  #       a + b
  #     end
  class Or
    self.send :include, Shared::InstanceMethods
    self.send :include, Shared::JoinTypeMethods
    self.extend Shared::ClassMethods

    # Creates a type constraint as a union of the supplied types.
    # @param a [#===|Array|Hash] the constraints to union
    # @param b [#===|Array|Hash] the constraints to union
    # @param rest [Array[#===|Array|Hash]] additional constraints to union
    # @return [Or<a, b, *rest>] the union of the given types
    def self.[](a, b, *rest)
      self.new(a, b, *rest)
    end

    # @implicit
    # (see [])
    def initialize(a, b, *rest)
      @args = @types = [a, b, *rest]
      @predicate = :any?
      class << @contract = Encase::Contract.new
        def success(*); true; end
        def failure(*); false; end
      end
    end
  end

  # The {Xor} type creates a new type that meets exactly one of the given
  # constraints.
  #
  #     Contract Xor[Array, String, proc { |x| x.length > 10 }] => Fixnum
  #     def short_length(x)
  #       x.length
  #     end
  class Xor
    self.send :include, Shared::InstanceMethods
    self.send :include, Shared::JoinTypeMethods
    self.extend Shared::ClassMethods

    # Creates a type constraint as an exclusive union of the supplied types.
    # @param a [#===|Array|Hash] the constraints to union
    # @param b [#===|Array|Hash] the constraints to union
    # @param rest [Array[#===|Array|Hash]] additional constraints to union
    # @return [Xor<a, b, *rest>] the exclusive union of the given types
    def self.[](a, b, *rest)
      self.new(a, b, *rest)
    end

    # @implicit
    # (see [])
    def initialize(a, b, *rest)
      @args = @types = [a, b, *rest]
      @predicate = :one?
      class << @contract = Encase::Contract.new
        def success(*); true; end
        def failure(*); false; end
      end
    end
  end

  # The {Not} type inverts the constraint of the given type.
  #
  #     Contract Not[Fixnum] => Fixnum
  #     def opinionated(x)
  #       raise "Hey!" if x.is_a? Fixnum
  #       x.__id__
  #     end
  class Not
    self.send :include, Shared::InstanceMethods
    self.extend Shared::ClassMethods

    # Creates a type constraint as a negation of the supplied type.
    # @param type [#===] the constraint to negate
    # @return [Not<type>] a constraint that validates the inverse constraint
    def self.[](type)
      self.new(type)
    end

    # @implicit
    # (see [])
    def initialize(type)
      @args = [type]
      @type = type
      raise Encase::Contract::MalformedContractError.new self,
        "Cannot negate a parameterized Code constraint" if @type.is_a?(Code)
    end

    # Validate that the argument does not match the supplied type.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      !(@type === obj)
    end
  end

  # @!parse
  #  # The {Int} type is a shorthand for validating integer values.
  #  #
  #  #     Contract Any => Int
  #  #     def get_id(obj)
  #  #       obj.__id__
  #  #     end
  #  class Int; end
  const_set(:Int, Integer)

  # @!parse
  #  # The {Num} type is a shorthand for validating all valid numeric values.
  #  #
  #  #     Contract Num, Num => Num
  #  #     def time(x, y)
  #  #       x * y
  #  #     end
  #  class Num; end
  const_set(:Num, Numeric)

  # The {Bool} type gives you a way to describe strict boolean values.
  #
  #     Contract Num => Bool
  #     def multiple_of_two(x)
  #       x.even?
  #     end
  class Bool
    self.extend Shared::ClassMethods

    # Validate that the argument is either `true` or `false`.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      [true, false].include? obj
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
    self.extend Shared::ClassMethods

    # Exposes the implied contract.
    attr_accessor :contract

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

    # @implicit
    # Generates a readable string representation of the constraint.
    # @return [String] a description of this constraint
    def to_s
      "#{self.class}[#{Encase::Contract.generate_signature(@contract.constraints)}]"
    end
    alias_method :inspect, :to_s
  end

  # The {Test} type introduces a facility for validating objects by directly
  # querying the objects themselves.  Particularly useful with predicate
  # methods, this allows you two quickly write checks and comparisons you
  # might otherwise write a Proc for.
  #
  #     Contract Test[:empty?]
  #     def append_to_empty_collection(collection)
  #       collection << 1 << 2 << 3
  #     end
  #
  #     Contract Test[:>=, 0] => Fixnum
  #     def decrement(n)
  #       n - 1
  #     end
  class Test
    self.send :include, Shared::InstanceMethods
    self.extend Shared::ClassMethods

    # Creates a new {Test} constraint, which validates values by invoking
    # methods on the object being tested.
    # @param method [Symbol] the method to test
    # @param types [Array[Any]] any additional arguments to send to the method
    # @return [Test<method, *types>] a constraint that will execute the method
    #         with the given arguments, expecting a truthy value
    def self.[](method, *types)
      self.new(method, *types)
    end

    # @implicit
    # (see [])
    def initialize(method, *types)
      @args = [method, *types]
    end

    # Validate that the specified method (with the given arguments) returns a
    # truthy value.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      obj.send(*@args) rescue false
    end
  end

  # The {Can} type is a specialization of {Test}, which specifically tests
  # whether values `#respond_to?` the named method.  Multiple methods may be
  # named; all must be supported to validate.
  #
  #     Contract Can[:to_s] => String
  #     def stringify(obj)
  #       obj.to_s
  #     end
  #
  #     Contract Can[:save, :load] => Bool
  #     def update(obj)
  #       obj.load
  #       obj.updated = DateTime.now
  #       obj.save
  #     end
  class Can < Test

    # Validate that the specified object responds to all given messages.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      @args.all? { |m| obj.respond_to?(m) rescue false }
    end
  end

  # The {List} type is allows you to describe Enumerables, and to validate
  # their contents against a list of constraints.  Multiple constraints will
  # be joined as an {Or}.
  #
  #     Contract List
  #     def enumerate(list)
  #       list.each { |x| ... }
  #     end
  #
  #     Contract List[String] => Bool
  #     def concat(list)
  #       list.join(', ')
  #     end
  #
  #     Contract List[/^\d+$/, Fixnum] => List[Fixnum]
  #     def numbers(list)
  #       list.map { |x| x.to_i }
  #     end
  class List
    self.send :include, Shared::InstanceMethods
    self.extend Shared::ClassMethods

    # Creates a new {List} constraint, which tests that all elements of an
    # Enumerable pass one of the given constraints.
    # @param types [Array[#===|Array|Hash]] a list of constraints to test
    # @return [List<*types>] a constraint that tests enumerables against a set
    #         of constraints
    def self.[](*types)
      self.new(*types)
    end

    # Validate that the argument is an Enumerable.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def self.===(obj)
      obj.is_a? Enumerable
    end

    # @implicit
    # (see [])
    def initialize(*types)
      @args = types.dup
      types.push(None) until types.length >= 2
      @constraint = Or[*types]
    end

    # Validate that the specified object is an enumerable, and that all of its
    # elements are one of the given types.
    # @param obj [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(obj)
      self.class === obj && obj.all? { |e| @constraint === e }
    end
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
    self.send :include, Shared::InstanceMethods
    self.extend Shared::ClassMethods

    # Creates a new constraint for describing the type of zero or more
    # arguments in a list.
    # @param type [#===|Array|Hash] the constraint to apply to the arguments
    # @return [Splat<type>] a constraint that validates zero or more arguments
    def self.[](type)
      self.new(type)
    end

    # @implicit
    def initialize(type)
      @args = [type]
      @type = type
    end

    # Validate that the argument conforms to the given interface.
    # @param val [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(val)
      @type === val
    end

    # Is this an optional parameter?
    # @return [Bool] always returns `true`
    def optional?
      true
    end
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

    # Is this a non-argument parameter?
    # @return [Bool] always returns `true`
    def non_argument?
      true
    end
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

    # Is this a non-argument parameter?
    # @return [Bool] always returns `true`
    def non_argument?
      true
    end

    # Validate that the return value conforms to the given interface.
    # @param val [Object] the value to validate
    # @return [Boolean] the result of the validation
    def ===(val)
      value === val
    end

    # @implicit
    # Allows us to avoid adding any additional parameter constraints.
    def keys; []; end

    # Returns the wrapped value.  If the wrapped value is itself a {Returns},
    # the inner value is retrieved instead.
    # @return [Object] the wrapped value
    def value
      values[0].is_a?(self.class) ? values[0].value : values[0]
    end

    # @implicit
    # Provide a recognizable string representation.
    def to_s; "Returns[#{value.inspect}]"; end
    alias_method :inspect, :to_s
  end

  # @implicit
  # Including this module will include the `Contract` decorator method.
  # @param base [Class] the class including this module
  def self.included(base)
    base.send(:include, Encase::Contract.module)
  end
end

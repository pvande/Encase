require 'encase/decorator'
require 'encase/contracts'

module Encase
  # A Contract is a type of Decorator for describing the expected inputs and
  # outputs of a function or method.  In statically typed languages, these
  # constraints are typically validated at compile time; i  n the
  # Decorator-based implementation, we defer most of the validation as late as
  # possible.  This gives us the ability to describe a much richer type
  # system, at the cost of not being able to statically prove our software
  # "correct".
  #
  # If you're interested in changing the behavior of constraint validation
  # (e.g. cause failures to generate warnings instead of errors), the
  # {#success} and {#failure} callbacks are invoked following the validation
  # of each value, and can easily be overridden.  Returning a `false` value
  # from either callback will prevent further execution, while returning a
  # `true` value will allow execution to continue.
  class Contract < Decorator

    # Exposes the constraints enforced by this Contract.
    attr_accessor :constraints

    # Create a new Contract with the given arguments.  These arguments will be
    # validated against the arguments of the wrapped callable.  If the last
    # argument is an instance of the {Contracts::Returns} type, will be used
    # to validate the return value of the callable.  As a shorthand, if the
    # last argument is a single-element Hash, it will be destructured into a
    # (final argument, returned value) pair.  This allows you to write
    # Contracts that read more clearly in most common cases.
    #
    # @example Explicit {Contracts::Returns} Type
    #   Contract.new Returns[String]
    #   Contract.new String, Fixnum, { :count => Fixnum }, Returns[String]
    # @example Shorthand Return Type Validation
    #   Contract.new Fixnum, Fixnum => Fixnum
    # @param args [Array[#===]] a list of parameter constraints
    def initialize(*args)
      if args.last.is_a?(Hash) && args.last.size == 1
        self.constraints = {
          :args   => args[0...-1] + args.last.keys,
          :return => args.last.values.last
        }
      else
        self.constraints = { :args => args }
      end

      # If we were invoked with only a {Contracts::Returns} constraint, we
      # should avoid trying to validate any of the parameters.
      if args.last.is_a?(Encase::Contracts::Returns) && args.size == 1
        constraints.delete :args
      end

      # Check for superfluous {Returns}
      find_overzealous_returns constraints[:args] if constraints.has_key? :args
      if constraints[:return] == Encase::Contracts::Returns
        find_overzealous_returns([constraints[:return]])
      end

      # Check for superfluous {Splat}
      find_overzealous_splats constraints[:args] if constraints.has_key? :args
    end

    # @!group Contract Validation Callbacks

    # Called after each successful validation.
    #
    # Truthy return values will allow proceed as normal, while falsey return
    # values will arrest further execution.
    # @param data [Hash] information about the successful comparison
    # @return [Boolean] always returns `true`
    def success(data)
      true
    end

    # Called after each failed validation.
    #
    # Truthy return values will allow proceed as normal, while falsey return
    # values will arrest further execution.
    # @param data [Hash] information about the successful comparison
    # @return [Boolean] always raises exception
    def failure(data)
      raise ContractViolationException.new(self, data.merge(:loc => location))
    end

    private

    # @!group Decorator Overrides

    # Decorates the wrapped callable with paramater and return value
    # validations.  Returns `nil` if any validation callback returns false.
    # @param (see Decorator#around)
    # @return [Object] if all validations succeed, this method returns the
    #         result of calling `code`
    # @return [nil] if any validation fails
    # @see #success
    # @see #failure
    # @see Decorator#around
    def around(code, args, block)
      if constraints.has_key?(:args)
        return unless validate(constraints[:args], args)
      end
      code.call(*args, &block).tap do |retval|
        if constraints.has_key?(:return)
          return unless validate([constraints[:return]], [retval])
        end
      end
    end

    # These methods are obsoleted by this subclass.
    # @!method before
    #   @obsolete
    # @!method after
    #   @obsolete
    undef_method :before, :after

    # @!endgroup

    # Handle the actual work of validation.  For the common case, this is as
    # simple as comparing the elements of the `constraints` list against the
    # values of the `args` list.  That approach works fine for simple lists,
    # but we also try to do basic destructuring as well, recursively
    # validating Arrays and Hashes.
    # @param consts [Array[#===|Array|Hash]] the set of constraints for
    #        parameter validation
    # @param args [Array] the set of values for parameter validation
    # @return [Boolean] the result of the validation
    def validate(consts, args)
      constraints, arguments = consts.dup, args.dup

      while true
        if arguments.empty?
          return true if constraints.empty?
          return true if constraints.map(&:class) == [Encase::Contracts::Splat]
        elsif constraints.empty?
          return failure(:constraint => consts, :value => args)
        end

        const, arg = constraints.shift, arguments.shift

        if const.is_a?(Encase::Contracts::Splat)
          constraints.unshift(const)      if constraints.size < arguments.size
          arguments.unshift(arg) and next if constraints.size > arguments.size
        end

        result = if const.is_a? Array
          validate(const, arg) if arg.is_a?(Array)
        elsif const.is_a?(Hash) && arg.is_a?(Hash)
          validate(*const.keys.map { |k| [const[k], arg[k]] }.transpose)
        else
          # Ruby 1.9 makes Proc#=== magical, but Ruby 1.8.7 doesn't support it
          (const.is_a?(Proc) ? const[arg] : const === arg).tap do
            # Speaking of magic, we want to make sure that any code we're
            # decorating actually checks its types.  To make that happen,
            # we'll just do a little slight-of-hand on the `args` list here…
            if const.is_a?(Encase::Contracts::Code)
              args[args.length - arguments.length - 1] = const.wrap(arg)
            end
          end
        end

        data = { :constraint => const, :value => arg }
        return false unless (result ? success(data) : failure(data))
      end
    end

    # Handle discovery of overzealous application of the {Contracts::Returns}
    # type.  The constraint should always be the last element of the contract,
    # and should never be nested under a data structure.
    # @param args [Array[#===|Array|Hash]] the constraints to validate
    # @return [void]
    def find_overzealous_returns(args)
      not_a_constraint = proc do |v|
        raise MalformedContractError.new self,
          "`Returns` is not a constraint; " +
          "please supply a parameter (e.g. `Returns[String]`)"
      end
      invalid_value = proc do |v|
        raise MalformedContractError.new self,
          "`#{v.inspect}` cannot be used as a value; " +
          "it must be the last value of the Contract"
      end

      args.each do |arg|
        not_a_constraint[arg] if arg == Encase::Contracts::Returns

        case arg
        when Encase::Contracts::Returns
          invalid_value[arg]
        when Array
          find_overzealous_returns(arg)
        when Hash
          arg.values.each do |v|
            not_a_constraint[v] if v == Encase::Contracts::Returns

            case v
            when Array
              find_overzealous_returns(v)
            when Encase::Contracts::Returns
              invalid_value[v]
            end
          end
        end
      end
    end

    # Handle discovery of overzealous application of the {Contracts::Splat}
    # type.  In particular there's no good way to resolve a list with more
    # than one splat; in an effort to discourage ambiguous contracts, we'll
    # fail if we see two {Contracts::Splat}s in a single list.
    # @param args [Array[#===|Array|Hash]] the constraints to validate
    # @return [void]
    def find_overzealous_splats(args)
      seen_splats = 0
      args.each do |arg|
        if arg == Encase::Contracts::Splat
          raise MalformedContractError.new self,
            "`Splat` is not a constraint; " +
            "please supply a parameter (e.g. `Splat[String]`)"
        end

        case arg
        when Encase::Contracts::Splat
          if (seen_splats += 1) > 1
            raise MalformedContractError.new self,
              "Only one `Splat` can be used in each list in a contract"
          end
        when Array
          find_overzealous_splats(arg)
        when Hash
          arg.values.each do |v|
            case v
            when Array
              find_overzealous_splats(v)
            when Encase::Contracts::Splat
              raise MalformedContractError.new self,
                "`Splat` cannot be used as a Hash value; " +
                "try wrapping it in an array first (e.g. `[Splat[String]]`)"
            end
          end
        end
      end
    end

    # @implicit
    # Generates a readable string representation of the Contract.
    # @return [String] a description of this Contract
    def to_s
      sig = "Contract "
      if constraints.has_key? :args
        sig += constraints[:args].map(&:inspect).join(', ')
        sig += " => "
        sig += constraints[:return].inspect if constraints.has_key? :return
      elsif constraints.has_key? :return
        sig += "Return[#{constraints[:return].inspect}]"
      else
        sig = "Contract()"
      end
   end

    # Raised by the default implementation of {Contract#failure}, this
    # exception represents an attempt to improperly invoke a function with an
    # explicit type constraint.
    #
    # This deliberately subclasses Exception to avoid being accidentally
    # swallowed by overzealous `rescue` blocks.
    class ContractViolationException < Exception
      def initialize(contract, data)
        klass       = contract.decorated_class
        method      = contract.decorated_method
        location    = contract.location

        msg = "\nContract Violation for "
        msg += if klass.ancestors.include?(Class)
          "#{klass.inspect[/^#<Class:(.*)>$/,1]}.#{method}:"
        else
          "#{klass}##{method}:"
        end
        msg += "\n(declared in #{location})"
        msg += "\n  #{contract}"
        msg += "\n  Expected #{data[:constraint].inspect}"
        msg += "\n  Received #{data[:value].inspect}"

        super msg
      end
    end

    # This is raised by the constructor when the passed parameters cannot be
    # sensibly interpreted.  The current set of cases which may raise this
    # exception are as follows:
    #
    #   * An instance of {Contracts::Returns} used as a non-terminal constraint
    #   * {Contracts::Returns} itself used as a constraint
    class MalformedContractError < StandardError
      def initialize(contract, message)
        msg = "\nMalformed Contract for"
        msg += "\n  #{contract}"
        msg += "\n  #{message}"
        
        super msg
      end
    end
  end
end

require 'encase/decorator'

module Encase
  # A Contract is a type of Decorator for describing the expected inputs and
  # outputs of a function or method.  In statically typed languages, these
  # contracts are typically validated at compile time; in the Decorator-based
  # implementation, we defer most of the validation as late as possible.  This
  # gives us the ability to describe a much richer type system, at the cost of
  # not being able to statically prove our software "correct".
  #
  # If you're interested in changing the behavior of contract validation (e.g.
  # cause failures to generate warnings instead of errors), the {#success} and
  # {#failure} callbacks are invoked following the validation of each value,
  # and can easily be overridden.  Returning a +false+ value from either
  # callback will prevent further execution, while returning a +true+ value
  # will allow execution to continue.
  class Contract < Decorator

    # Create a new Contract with the given arguments.  These arguments will be
    # validated against the arguments of the wrapped callable.  If the last
    # argument is a single-element Hash, the key of that hash is used as the
    # final argument validator, and the value of that hash is used to validate
    # the return value.  This allows you to write Contracts that read more
    # clearly in most common cases.
    # @param args [Array[#===]] a list of parameter matchers
    def initialize(*args)
      if args.last.is_a?(Hash) && args.last.size == 1
        @matchers = {
          :args   => args[0...-1] + args.last.keys,
          :return => args.last.values.last
        }
      else
        @matchers = { :args => args }
      end
    end

    # @!group Contract Validation Callbacks

    # Called after each successful validation.
    #
    # Truthy return values will allow proceed as normal, while falsey return
    # values will arrest further execution.
    # @param data [Hash] information about the successful comparison
    # @return +true+
    def success(data)
      true
    end

    # Called after each failed validation.
    #
    # Truthy return values will allow proceed as normal, while falsey return
    # values will arrest further execution.
    # @param data [Hash] information about the successful comparison
    def failure(data)
      raise ContractViolationException.new(data)
    end

    private

    # @!group Decorator Overrides

    # Decorates the wrapped callable with paramater and return value
    # validations.  Returns +nil+ if any validation callback returns false.
    # @see #success
    # @see #failure
    # @see Decorator#around
    def around(code, args, block)
      return unless validate(@matchers[:args], args)
      code.call(*args, &block).tap do |retval|
        if @matchers.has_key?(:return)
          return unless validate([@matchers[:return]], [retval])
        end
      end
    end

    # @!endgroup

    # Handle the actual work of validation.  For the common case, this is as
    # simple as comparing the elements of the +matchers+ list against the
    # values of the +args+ list.  That approach works fine for simple lists,
    # but we also try to do basic destructuring as well, recursively validating
    # Arrays and Hashes.
    # @param matchers [Array[#===|Array|Hash]] the set of matchers for
    #        parameter validation
    # @param args [Array] the set of values for parameter validation
    # @return [Bool] the result of the validation
    def validate(matchers, args)
      unless args.size == matchers.size
        return failure(:matcher => matchers, :value => args, :loc => location)
      end

      matchers.zip(args).find do |match, arg|
        result = if match.is_a? Array
          validate(match, arg) if arg.is_a?(Array)
        elsif match.is_a?(Hash) && arg.is_a?(Hash)
          validate(*match.keys.map { |k| [match[k], arg[k]] }.transpose)
        else
          # Ruby 1.9 makes Proc#=== magical, but Ruby 1.8.7 doesn't support it.
          match.is_a?(Proc) ? match[arg] : match === arg
        end

        data = { :matcher => match, :value => arg, :loc => location }
        not (result ? success(data) : failure(data))
      end.nil?
    end

    # Raised by the default implementation of {Contract#failure}, this
    # exception represents an attempt to improperly invoke a function with an
    # explicit type contract.
    #
    # This deliberately subclasses Exception to avoid being accidentally
    # swallowed by overzealous +rescue+ blocks.
    class ContractViolationException < Exception
      def initialize(data)
        msg = "\nContract Violation for "
        msg += if decorated_class.ancestors.include?(Class)
          "#{decorated_class.inspect[/^#<Class:(.*)>$/, 1]}.#{decorated_method}:"
        else
          "#{decorated_class}##{decorated_method}:"
        end
        msg += "\n(declared in #{location})"
        msg += "\n  Contract #{@matchers[:args].join(', ')}"
        msg += " => #{@matchers[:return]}" if @matchers.has_key? :return
        msg += "\n  Expected #{data[:matcher].inspect}"
        msg += "\n  Received #{data[:value].inspect}"

        super msg
      end
    end
  end
end

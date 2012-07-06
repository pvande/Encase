module Encase
  # A basic implementation of the Decorator pattern.  An instance of a
  # decorator can "wrap" a callable type (like a Proc or a Method) and augment
  # their behavior.
  class Decorator

    # Wraps the given callable object in a Proc that passes it through to the
    # {#around} method (which itself delegates to {#before} and {#after}).
    # @param code [#call] the callable to augment
    # @return [Proc] a decorated callable
    def wrap_callable(code)
      decorator = self
      proc { |*args, &block| decorator.send(:around, code, args, block) }
    end

    private

    # Called from the wrapper Proc.
    # @api extender Intended to be an extension point for subclasses
    # @param code [#call] the callable being augmented
    # @param args [Array[Any]] the arguments the wrapper was invoked with
    # @param block [Proc] the block the wrapper was invoked with
    # @return the result of calling +code+
    def around(code, args, block)
      before(code, args, block)
      code.call(*args, &block).tap do |retval|
        after(code, args, block, retval)
      end
    end

    # Called before the wrapped callable.
    # @api extender Intended to be an extension point for subclasses
    # @param (see #around)
    def before(code, args, block); end

    # Called after the wrapped callable.
    # @api extender Intended to be an extension point for subclasses
    # @param code [#call] the callable being augmented
    # @param args [Array[Any]] the arguments the wrapper was invoked with
    # @param block [Proc] the block the wrapper was invoked with
    # @param retval [Any] the result of having called +code+
    def after(code, args, block, retval); end
  end
end

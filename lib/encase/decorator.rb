module Encase
  # A basic implementation of the Decorator pattern.  An instance of a
  # decorator can "wrap" a callable type (like a Proc or a Method) and augment
  # their behavior.
  class Decorator

    # @return [String] Location of the line that applied this decorator.
    attr_accessor :location

    # @return [Class] The class containing the decorated method.
    attr_accessor :decorated_class

    # @return [String] The name of the decorated method.
    attr_accessor :decorated_method

    # @return [Object] The object being decorated.
    attr_accessor :binding

    # Generate a module containing a method for applying the decorator.  This
    # may be named explicitly, but defaults to the same name as the class.
    # @param name [#to_s] the name of the decorator method
    # @return [Module] a module containing the decorator (and setup code)
    def self.module(name=self.name)
      if [nil, ''].include? name
        raise "Can't automatically detect name of anonymous classes"
      end

      name = "#{name}"[/[^:]*$/]
      mod = @modules[self][name]
      Module.new do
        # We want to include methods *only* into the class, not the instances.
        (class << self; self; end).send(:define_method, :included) do |base|
          if base == Object
            raise 'Please avoid including Decorators into the Object class.'
          end

          base.extend(mod)
        end
      end
    end

    @disabled = false

    # Disables all instances of this Decorator, and all instances of all
    # subclasses.  Disabled Decorators will bypass all non-essential
    # functionality, in favor of performance.
    def self.disable
      @disabled = true
    end

    # Is this Decorator type disabled?
    # @return [Boolean] `true` if this or any superclass of this decorator has
    #         been disabled; otherwise `false`
    def self.disabled?
      return @disabled if instance_variable_defined?(:@disabled) && @disabled
      superclass.disabled? if superclass.respond_to? :disabled?
    end

    # Is this Decorator instance disabled?
    # @return [Boolean] `true` if the decorator type is disabled, otherwise
    #         `false`
    def disabled?
      self.class.disabled?
    end

    # Wraps the given callable object in a Proc that passes it through to the
    # {#around} method (which itself delegates to {#before} and {#after}).
    # @param code [#call] the callable to augment
    # @return [Proc] a decorated callable
    def wrap_callable(code)
      decorator = self
      proc do |*args, &block|
        code = code.bind(self) if code.respond_to? :bind
        if decorator.disabled?
          code.call(*args, &block)
        else
          decorator.binding = self
          decorator.send(:around, code, args, block)
        end
      end
    end

    # Creates the appropriate hooks on the given module to observe one -- and
    # only one -- method definition, and wrap it in the appropriate decorator.
    # @param klass [Module] the module to establish observers on
    # @return [void]
    def watch(klass)
      deco = self
      meta = (class << klass; self; end)

      # We create hooks to handle added instance and class methods, caching
      # the existing methods before we do.
      hooks = {
        :method_added => {
          :into => klass,
          :orig => klass.method(:method_added),
        },
        :singleton_method_added => {
          :into => meta,
          :orig => klass.method(:singleton_method_added),
        },
      }

      # We have to do a little work to avoid recursion…
      hooks.each do |hook, opts|
        already_called = false
        meta.send(:define_method, hook) do |m|
          return if already_called || hooks.include?(m)
          already_called = true

          into = opts[:into]

          # … and to persist debugging information…
          deco.decorated_class  = into
          deco.decorated_method = m.to_s

          # … but when a new method is declared, we wrap it with the newly
          # created decorator instance…
          method = into.instance_method(m)
          into.send(:define_method, m, deco.wrap_callable(method))

          # … restore the original hooks, and invoke the original hook.
          hooks.each { |k,v| meta.send(:define_method, k, v[:orig]) }
          opts[:orig].call(m)
        end
      end
    end

    private

    # @!group Decorator Callbacks

    # Called from the wrapper Proc.
    # @api extender Intended to be an extension point for subclasses
    # @param code [#call] the callable being augmented
    # @param args [Array] the arguments the wrapper was invoked with
    # @param block [Proc] the block the wrapper was invoked with
    # @return the result of calling `code`
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
    # @param args [Array] the arguments the wrapper was invoked with
    # @param block [Proc] the block the wrapper was invoked with
    # @param retval [Any] the result of having called `code`
    def after(code, args, block, retval); end

    # @!endgroup

    # @implicit
    # Propagate the `@modules` variable to Decorator subclasses.
    # @param klass [Class] the subclass of {Decorator}
    def self.inherited(klass)
      klass.instance_variable_set(:@modules, @modules)
    end

    # The @modules variable is a cache of the Decorator modules we've created
    # thus far.  Each Decorator subclass gets a reference to this variable.
    # The Module itself is cached by subclass, then by name.
    @modules = Hash.new do |hash, decorator|
      hash[decorator] = Hash.new do |hash, name|
        hash[name] = Module.new do

          # The actual decorator method gathers the arguments (and the block)
          # and passes them through to the subclass' constructor.  We also
          # want to persist the location we were called from.
          define_method(name) do |*args, &block|
            deco = decorator.new(*args, &block)
            deco.location = caller(1)[0]
            deco.watch(self)
            return deco
          end
        end
      end
    end
  end
end

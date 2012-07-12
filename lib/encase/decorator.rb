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

    # Generate a module containing a method for applying the decorator.  This
    # may be named explicitly, but defaults to the same name as the class.
    # @param name [#to_s] the name of the decorator method
    # @return [Module] a module containing the decorator (and setup code)
    def self.module(name=self.name)
      raise "Can't automatically detect name of anonymous classes" if name.nil?
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

    # Wraps the given callable object in a Proc that passes it through to the
    # {#around} method (which itself delegates to {#before} and {#after}).
    # @param code [#call] the callable to augment
    # @return [Proc] a decorated callable
    def wrap_callable(code)
      decorator = self
      proc do |*args, &block|
        code = code.bind(self) if code.respond_to? :bind
        decorator.send(:around, code, args, block)
      end
    end

    private

    # @!group Decorator Callbacks

    # Called from the wrapper Proc.
    # @api extender Intended to be an extension point for subclasses
    # @param code [#call] the callable being augmented
    # @param args [Array[Any]] the arguments the wrapper was invoked with
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
    # @param args [Array[Any]] the arguments the wrapper was invoked with
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

          # The actual decorator method gathers the arguments (and the block)…
          define_method(name) do |*args, &block|

            # … and passes them through to the subclass' constructor.  We
            # also want to persist the location we were called from.
            deco = decorator.new(*args, &block)
            deco.location = caller(1)[0]

            self.instance_eval do
              meta = (class << self; self; end)
              define = :define_method

              # We create hooks to handle added instance and class methods,
              # caching the existing methods before we do.
              hooks = {
                :method_added           => { :into => self },
                :singleton_method_added => { :into => meta },
              }
              hooks.each { |k,v| v[:orig] = method(k) }

              # We have to do a little work to avoid recursion…
              hooks.each do |hook, opts|
                already_called = false
                meta.send(define, hook) do |m|
                  return if already_called || hooks.include?(m)
                  already_called = true

                  # … and to persist debugging information…
                  deco.decorated_class  = opts[:into]
                  deco.decorated_method = m.to_s

                  # … but when a new method is declared, we wrap it with the
                  # newly created decorator instance…
                  wrapped = deco.wrap_callable(opts[:into].instance_method(m))
                  opts[:into].send(define, m, wrapped)

                  # … restore the original hooks, and recurse.  Since each
                  # decorator restores the hook to its previous state, we'll
                  # terminate after invoking each applicable decorator.
                  hooks.each { |k,v| meta.send(define, k, v[:orig]) }
                  send(hook, m)
                end
              end
            end
          end
        end
      end
    end
  end
end

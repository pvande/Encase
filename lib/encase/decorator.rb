module Encase
  class Decorator
    def wrap_callable(code)
      decorator = self
      proc { |*args, &block| decorator.send(:around, code, args, block) }
    end

    private
    def around(code, args, block)
      before(code, args, block)
      code.call(*args, &block).tap do |retval|
        after(code, args, block, retval)
      end
    end

    def before(code, args, block); end
    def after(code, args, block, retval); end
  end
end

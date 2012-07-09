require 'encase/decorator'

describe Encase::Decorator do
  let(:decorator) { Encase::Decorator.new }
  let(:proc)      { Proc.new { |*| } }

  describe '.module' do
    subject { Disposable }

    before do
      class Disposable < Encase::Decorator
        class Diaper < Encase::Decorator; end
        def self.dynamic_subclass
          Class.new(Encase::Decorator)
        end
      end
    end

    after { Object.send :remove_const, :Disposable }

    it 'should create a module with a self-named function' do
      subject.module.instance_methods.map(&:to_s).should include('Disposable')
    end

    it 'should create a module with a self-named function despite namespace' do
      subject::Diaper.module.instance_methods.map(&:to_s).should include('Diaper')
    end

    it 'should create a module with a named function if given a name' do
      subject.module(:Foo).instance_methods.map(&:to_s).should include('Foo')
    end

    it 'should refuse to autoname a dynamic subclass' do
      expect { subject.dynamic_subclass.module }.to raise_exception
    end

    describe "(module use)" do
      subject { Class.new { include Disposable.module } }
      let(:metaclass) { class << subject; self; end }

      def decorator
        double(
          :location= => nil,
          :decorated_class= => nil,
          :decorated_method= => nil
        )
      end

      it 'should wrap existing method_added hooks' do
        Disposable.any_instance.should_receive(:wrap_callable).and_return(proc)
        subject.should_receive(:method_added).with(:foo)

        subject.class_eval do
          Disposable()
          def foo; end
        end
      end

      it 'should wrap the next declared method' do
        args, b = [ 1, :two, 'three' ], proc
        Disposable.any_instance.should_receive(:around).with(anything, args, b)

        subject.class_eval do
          Disposable()
          def foo(*args); end
          self.new.foo(*args, &b)
        end
      end

      it 'should still invoke the declared method' do
        args, b = [ 1, :two, 'three' ], proc
        subject.any_instance.should_receive(:bar).with(args, b)

        subject.class_eval do
          Disposable()
          def foo(*args, &b); bar(args, b); end
          self.new.foo(*args, &b)
        end
      end

      it 'should allow multiple decorators' do
        Disposable.should_receive(:new).with(1).and_return(a = decorator)
        Disposable.should_receive(:new).with(2).and_return(b = decorator)
        Disposable.should_receive(:new).with(3).and_return(c = decorator)

        c.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        b.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        a.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }

        subject.class_eval do
          Disposable(1)  # a
          Disposable(2)  # b
          Disposable(3)  # c
          def foo; end
        end
      end

      it 'should allow multiple decorators across multiple instance methods' do
        Disposable.should_receive(:new).with(1).and_return(a = decorator)
        Disposable.should_receive(:new).with(2).and_return(b = decorator)
        Disposable.should_receive(:new).with(3).and_return(c = decorator)
        Disposable.should_receive(:new).with(4).and_return(d = decorator)

        b.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        a.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        d.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'baz'; proc }
        c.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'baz'; proc }

        subject.class_eval do
          Disposable(1)  # a
          Disposable(2)  # b
          def foo; end
          def bar; end
          Disposable(3)  # c
          Disposable(4)  # d
          def baz; end
        end
      end

      it 'should allow multiple decorators across multiple mixed methods' do
        Disposable.should_receive(:new).with(1).and_return(a = decorator)
        Disposable.should_receive(:new).with(2).and_return(b = decorator)
        Disposable.should_receive(:new).with(3).and_return(c = decorator)
        Disposable.should_receive(:new).with(4).and_return(d = decorator)

        b.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        a.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'foo'; proc }
        d.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'baz'; proc }
        c.should_receive(:wrap_callable).ordered { |x| "#{x.name}".should == 'baz'; proc }

        subject.class_eval do
          Disposable(1)  # a
          Disposable(2)  # b
          def foo; end
          def bar; end
          Disposable(3)  # c
          Disposable(4)  # d
          def self.baz; end
        end
      end
    end
  end

  describe '#wrap_callable' do
    before  { @callee = double }
    subject { decorator.wrap_callable(@callee) }

    it 'should return a callable that passes along to Decorator#around' do
      decorator.should_receive(:around).with(@callee, ['x'], proc).and_return(:x)
      subject.call('x', &proc).should == :x
    end

    it 'should wrap Procs' do
      @callee = Proc.new { |*args, &block| args.inject(&block) }
      subject.call(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, &:+).should == 55
    end

    it 'should wrap Methods' do
      obj = Object.new
      def obj.injecter(*args, &block)
        args.inject(&block)
      end

      @callee = obj.method(:injecter)
      subject.call(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, &:-).should == -53
    end
  end

  describe '#around' do
    it 'should delegate to #before and #after' do
      wrapped = double
      args    = [1, 2, 3]
      ret     = double

      decorator.should_receive(:before).with(wrapped, args, proc).ordered
      wrapped.should_receive(:call).with(*args, &proc).ordered.and_return(ret)
      decorator.should_receive(:after).with(wrapped, args, proc, ret).ordered

      decorator.send(:around, wrapped, args, proc)
    end
  end
end

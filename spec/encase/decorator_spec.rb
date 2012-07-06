require 'encase/decorator'

describe Encase::Decorator do
  def generate_sentinel
    Object.new
  end

  let(:decorator) { Encase::Decorator.new }
  let(:proc)      { Proc.new { } }

  it { should respond_to :wrap_callable }

  describe '#wrap_callable' do
    before  { @callee = generate_sentinel() }
    subject { decorator.wrap_callable(@callee) }

    it 'should return a callable that passes along to Decorator#around' do
      decorator.should_receive(:around).with(@callee, ['x'], proc).once.and_return(:x)
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
      wrapped = generate_sentinel()
      args    = [1, 2, 3]
      ret     = generate_sentinel()

      decorator.should_receive(:before).with(wrapped, args, proc).ordered.once
      wrapped.should_receive(:call).with(*args, &proc).ordered.once.and_return(ret)
      decorator.should_receive(:after).with(wrapped, args, proc, ret).ordered.once

      decorator.send(:around, wrapped, args, proc)
    end
  end
end

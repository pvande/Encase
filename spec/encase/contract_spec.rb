require 'encase/contract'

describe Encase::Contract do
  before do
    @matchers = []
    @proc = Proc.new { |*| }
  end

  let(:contract) { Encase::Contract.new(*@matchers) }
  subject        { contract.wrap_callable(@proc) }

  describe '#validate' do
    def subject(*args)
      contract.send(:validate, *args)
    end

    before do
      contract.stub(:success) { true  }
      contract.stub(:failure) { false }
    end

    it 'should compare a list of contracts to a list of values' do
      subject([1, 2, 3], [1, 2, 3]).should be_true
      subject([1, 2, 3], [1, 2]).should be_false
      subject([1, 2, 3], [1, 2, nil]).should be_false
      subject([1, 2, 3], [1, 2, 3, 4]).should be_false
      subject([1, 2, 3], [1, 2, '3']).should be_false
    end

    it 'should permit typeclasses as contracts' do
      subject([Fixnum, String], [1, 'five']).should be_true
      subject([Fixnum, String], [1, 5]).should be_false
      subject([Fixnum, String], ['1', 'five']).should be_false
    end

    it 'should destructure arrays of contracts as necessary' do
      subject([[Fixnum], Symbol], [[1], :five]).should be_true
      subject([[Fixnum], Symbol], [[1, 2], :five]).should be_false
      subject([[Fixnum], Symbol], [1, :five]).should be_false
      subject([[Fixnum], Symbol], [['1'], :five]).should be_false
      subject([[Fixnum], Symbol], [[Fixnum], :five]).should be_false
    end

    it 'should destructure hashes of contracts as necessary' do
      subject([{:a => Fixnum}], [{:a => 1}]).should be_true
      subject([{:a => Fixnum}], [{:a => 1, :b => 2}]).should be_true
      subject([{:a => Fixnum}], [{:a => Fixnum}]).should be_false
      subject([{:a => Fixnum}], [{:b => 2}]).should be_false
    end

    it 'should use case-style tests for validation' do
      (tester = double()).stub(:===) { |x| !x.nil? }
      subject([tester], [1]).should be_true
      subject([tester], [nil]).should be_false
      subject([1..3], [1]).should be_true
      subject([1..3], [3]).should be_true
      subject([1..3], [0]).should be_false
      subject([1..3], [4]).should be_false
      subject([/x/], ['x']).should be_true
      subject([/x/], ['y']).should be_false
    end

    it 'should permit Procs for validation' do
      subject([:nil?.to_proc], [nil]).should be_true
      subject([:nil?.to_proc], [1]).should be_false
    end

    it 'should invoke the success callback for each successful validation' do
      contract.location = loc = double
      data = [
        { :matcher => Fixnum, :value => 1,   :loc => loc },
        { :matcher => (1..2), :value => 2,   :loc => loc },
        { :matcher => /\d/,   :value => '3', :loc => loc },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:success).with(args).ordered.and_return(true)
      end

      subject *data.map { |x| x.values_at(:matcher, :value) }.transpose
    end

    it 'should invoke the failure callback for each unsuccessful validation' do
      contract.location = loc = double
      data = [
        { :matcher => Fixnum, :value => :a, :loc => loc },
        { :matcher => (1..2), :value => :b, :loc => loc },
        { :matcher => /\d/,   :value => :c, :loc => loc },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:failure).with(args).ordered.and_return(true)
      end

      subject *data.map { |x| x.values_at(:matcher, :value) }.transpose
    end

    it 'should invoke the success callback for each successful array value' do
      contract.location = loc = double
      matcher = [ Fixnum, (1..2), /\d/ ]
      hash = { :matcher => matcher, :loc => loc }

      value = [1, 2, '1']
      (matcher.zip(value) << [matcher, value]).each do |matcher, val|
        val = hash_including(hash.merge(:matcher => matcher, :value => val))
        contract.should_receive(:success).with(val).and_return(true)
      end
      subject [matcher], [value]
    end

    it 'should invoke the failure callback for unsuccessful array values' do
      contract.location = loc = double
      matcher = [ Fixnum, (1..2), /\d/ ]
      hash = { :matcher => matcher, :loc => loc }

      val = hash_including(hash.merge(:value => :x))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [matcher], [:x]

      val = hash_including(hash.merge(:value => [:x]))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [matcher], [[:x]]

      val = hash_including(hash.merge(:value => [:w, :x, :y, :z]))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [matcher], [[:w, :x, :y, :z]]

      value = [ :a, :b, nil ]
      matcher.zip(value).each do |m, v|
        args = hash_including(hash.merge(:matcher => m, :value => v))
        contract.should_receive(:failure).with(args).and_return(true)
      end
      subject [matcher], [value]
    end

    it 'should invoke the success callback for successful hash values' do
      contract.location = loc = double
      matcher = { :a => Fixnum, :b => (1..2), :c => /\d/ }
      hash = { :matcher => matcher, :loc => loc }

      data = [
        { :matcher => Fixnum, :value => 1,   :loc => loc },
        { :matcher => (1..2), :value => 2,   :loc => loc },
        { :matcher => /\d/,   :value => '3', :loc => loc },
      ]
      
      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:success).with(args).and_return(true)
      end
      
      subject [matcher], [{ :b => 2, :a => 1, :c => '3', :d => :d }]
    end

    it 'should invoke the failure callback for unsuccessful hash values' do
      contract.location = loc = double
      matcher = { :a => Fixnum, :b => (1..2), :c => /\d/ }
      hash = { :matcher => matcher, :loc => loc }

      val = hash_including(hash.merge(:value => :x))
      contract.should_receive(:failure).with(val).and_return(false)

      subject [matcher], [:x]

      data = [
        { :matcher => Fixnum, :value => :a,  :loc => loc },
        { :matcher => (1..2), :value => :b,  :loc => loc },
        { :matcher => /\d/,   :value => nil, :loc => loc },
      ]
      
      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:failure).with(args).and_return(true)
      end
      
      subject [matcher], [{ :b => :b, :a => :a, :d => :d }]
    end
  end

  describe '#around' do
    def subject(*args, &block)
      contract.send(:around, @proc, args, block)
    end

    it 'should validate the passed arguments' do
      @matchers = [(x=double), (y=double), (z=double)]
      contract.should_receive(:validate).with([x, y, z], [1, 2, 3])
      subject(1, 2, 3)
    end

    it 'should validate the return value if given one' do
      @proc = proc { |x, y| x + y * 2 }
      @matchers = [(x=double), { (y=double) => (output=double) }]
      contract.should_receive(:validate).with([x, y], [3, 2]).and_return(true)
      contract.should_receive(:validate).with([output], [7])
      subject(3, 2)
    end
  end
end
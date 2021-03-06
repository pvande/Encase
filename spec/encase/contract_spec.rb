require 'spec_helper'
require 'encase/contract'

describe Encase::Contract do
  before do
    @constraints = []
    @proc = Proc.new { |*| }
  end

  let(:contract) { Encase::Contract.new(*@constraints) }
  subject        { contract.wrap_callable(@proc) }

  describe '#validate' do
    def subject(*args)
      contract.validate(*args)
    end

    before do
      contract.stub(:success) { true  }
      contract.stub(:failure) { false }
    end

    it 'should compare a list of contracts to a list of values' do
      subject([1, 2, 3], [1, 2, 3]).should be true
      subject([1, 2, 3], [1, 2]).should be false
      subject([1, 2, 3], [1, 2, nil]).should be false
      subject([1, 2, 3], [1, 2, 3, 4]).should be false
      subject([1, 2, 3], [1, 2, '3']).should be false
    end

    it 'should permit typeclasses as contracts' do
      subject([Fixnum, String], [1, 'five']).should be true
      subject([Fixnum, String], [1, 5]).should be false
      subject([Fixnum, String], ['1', 'five']).should be false
    end

    it 'should destructure arrays of contracts as necessary' do
      subject([[Fixnum], Symbol], [[1], :five]).should be true
      subject([[Fixnum], Symbol], [[1, 2], :five]).should be false
      subject([[Fixnum], Symbol], [1, :five]).should be false
      subject([[Fixnum], Symbol], [['1'], :five]).should be false
      subject([[Fixnum], Symbol], [[Fixnum], :five]).should be false
    end

    it 'should destructure hashes of contracts as necessary' do
      subject([{:a => Fixnum}], [{:a => 1}]).should be true
      subject([{:a => Fixnum}], [{:a => 1, :b => 2}]).should be true
      subject([{:a => Fixnum}], [{:a => Fixnum}]).should be false
      subject([{:a => Fixnum}], [{:b => 2}]).should be false
    end

    it 'should use case-style tests for validation' do
      (tester = double()).stub(:===) { |x| !x.nil? }
      subject([tester], [1]).should be true
      subject([tester], [nil]).should be false
      subject([1..3], [1]).should be true
      subject([1..3], [3]).should be true
      subject([1..3], [0]).should be false
      subject([1..3], [4]).should be false
      subject([/x/], ['x']).should be true
      subject([/x/], ['y']).should be false
    end

    it 'should permit Procs for validation' do
      subject([:nil?.to_proc], [nil]).should be true
      subject([:nil?.to_proc], [1]).should be false
    end

    it 'should invoke the success callback for each successful validation' do
      data = [
        { :constraint => Fixnum, :value => 1   },
        { :constraint => (1..2), :value => 2   },
        { :constraint => /\d/,   :value => '3' },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:success).with(args).ordered.and_return(true)
      end

      subject *data.map { |x| x.values_at(:constraint, :value) }.transpose
    end

    it 'should invoke the failure callback for each unsuccessful validation' do
      data = [
        { :constraint => Fixnum, :value => :a },
        { :constraint => (1..2), :value => :b },
        { :constraint => /\d/,   :value => :c },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:failure).with(args).ordered.and_return(true)
      end

      subject *data.map { |x| x.values_at(:constraint, :value) }.transpose
    end

    it 'should invoke the success callback for each successful array value' do
      contract.location = loc = double
      constraint = [ Fixnum, (1..2), /\d/ ]

      value = [1, 2, '1']
      (constraint.zip(value) << [constraint, value]).each do |const, val|
        val = hash_including(:constraint => const, :value => val)
        contract.should_receive(:success).with(val).and_return(true)
      end
      subject [constraint], [value]
    end

    it 'should invoke the failure callback for unsuccessful array values' do
      contract.location = loc = double
      constraint = [ Fixnum, (1..2), /\d/ ]
      hash = { :constraint => constraint }

      val = hash_including(hash.merge(:value => :x))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [constraint], [:x]

      val = hash_including(hash.merge(:value => [:x]))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [constraint], [[:x]]

      val = hash_including(hash.merge(:value => [:w, :x, :y, :z]))
      contract.should_receive(:failure).with(val).and_return(true)
      subject [constraint], [[:w, :x, :y, :z]]

      value = [ :a, :b, nil ]
      constraint.zip(value).each do |m, v|
        args = hash_including(hash.merge(:constraint => m, :value => v))
        contract.should_receive(:failure).with(args).and_return(true)
      end
      subject [constraint], [value]
    end

    it 'should invoke the success callback for successful hash values' do
      contract.location = loc = double
      constraint = { :a => Fixnum, :b => (1..2), :c => /\d/ }

      data = [
        { :constraint => Fixnum, :value => 1   },
        { :constraint => (1..2), :value => 2   },
        { :constraint => /\d/,   :value => '3' },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:success).with(args).and_return(true)
      end

      subject [constraint], [{ :b => 2, :a => 1, :c => '3', :d => :d }]
    end

    it 'should invoke the failure callback for unsuccessful hash values' do
      contract.location = loc = double
      constraint = { :a => Fixnum, :b => (1..2), :c => /\d/ }
      hash = { :constraint => constraint }

      val = hash_including(hash.merge(:value => :x))
      contract.should_receive(:failure).with(val).and_return(false)

      subject [constraint], [:x]

      data = [
        { :constraint => Fixnum, :value => :a  },
        { :constraint => (1..2), :value => :b  },
        { :constraint => /\d/,   :value => nil },
      ]

      data.each do |x|
        args = hash_including(x)
        contract.should_receive(:failure).with(args).and_return(true)
      end

      subject [constraint], [{ :b => :b, :a => :a, :d => :d }]
    end
  end

  describe '#around' do
    def subject(*args, &block)
      contract.send(:around, @proc, args, block)
    end

    def constraint
      double(:non_argument? => false)
    end

    it 'should validate the passed arguments' do
      @constraints = [(x=constraint), (y=constraint), (z=constraint)]
      contract.should_receive(:validate).with([x, y, z], [1, 2, 3])
      subject(1, 2, 3)
    end

    it 'should validate the return value if given one' do
      @proc = proc { |x, y| x + y * 2 }
      @constraints = [(x=constraint), {(y=constraint) => (output=constraint)}]
      contract.should_receive(:validate).with([x, y], [3, 2]).and_return(true)
      contract.should_receive(:validate).with([output], [7])
      subject(3, 2)
    end
  end

  describe '#inspect' do
    def Contract(*args)
      "#{Encase::Contract.new(*args).send(:inspect)}"
    end

    it 'should attempt to describe the constraint readably' do
      Contract().should == "Contract()"
      Contract(Fixnum, Fixnum).should == "Contract Fixnum, Fixnum"
      Contract(Fixnum, Returns[String]).should == "Contract Fixnum => String"
      Contract(Returns[String]).should == "Contract Returns[String]"
      Contract(Block => Returns[String]).should == "Contract Block => String"
      Contract(Block[Fixnum] => Returns[String]).should == "Contract Block[Fixnum] => String"
      Contract(Fixnum, Block[Fixnum] => Returns[String]).should == "Contract Fixnum, Block[Fixnum] => String"
    end
  end
end

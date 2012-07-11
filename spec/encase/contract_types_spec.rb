require 'spec_helper'
require 'encase/contracts'

describe "[Abstract Type Constraints]" do
describe Encase::Contracts::Any do
  Any = Encase::Contracts::Any

  def contract(*args)
    Encase::Contract.new(*args)
  end

  it 'should validate any value' do
    contract = contract(Any)
    contract.should_receive(:failure).exactly(0).times
    [ 1, :two, 'three', proc { :four }, nil, Object.new, Class ].each do |val|
      contract.send(:around, proc { }, [val], nil)
    end

    contract = contract(nil, Any)
    contract.should_receive(:failure).exactly(0).times
    [ 1, :two, 'three', proc { :four }, nil, Object.new, Class ].each do |val|
      contract.send(:around, proc { }, [nil, val], nil)
    end

    contract = contract(nil, [Any])
    contract.should_receive(:failure).exactly(0).times
    [ 1, :two, 'three', proc { :four }, nil, Object.new, Class ].each do |val|
      contract.send(:around, proc { }, [nil, [val]], nil)
    end
  end

  it 'should fail to validate the lack of any value' do
    contract = contract(Any)
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [], nil)
  end

  it 'should self-describe' do
    "#{Any}".should == 'Any'
  end
end

describe Encase::Contracts::None do
  None = Encase::Contracts::None

  def contract(*args)
    Encase::Contract.new(*args)
  end

  it 'should refuse to validate any value' do
    contract = contract(None)
    contract.should_receive(:failure).exactly(7).times
    [ 1, :two, 'three', proc { :four }, nil, Object.new, Class ].each do |val|
      contract.send(:around, proc { }, [val], nil)
    end
  end

  it 'should validate the lack of any value' do
    contract = contract(None)
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [], nil)

    contract = contract(Fixnum, None)
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(Fixnum, [None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1, []], nil)
  end

  it 'should self-describe' do
    "#{None}".should == 'None'
  end
end
end

describe "[Type Constraints]" do
describe Encase::Contracts::Code do
  Code = Encase::Contracts::Code

  def contract(*args)
    Encase::Contract.new(*args)
  end

  describe 'without parameters' do
    it 'should validate that the value is a Proc or Method' do
      contract = contract(Code)
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [proc { }], nil)

      contract = contract(Code)
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [self.method(:example)], nil)

      contract = contract(Code, Code)
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [proc { }, proc { }], nil)

      contract = contract(Code)
      contract.should_receive(:failure).exactly(1).times
      contract.send(:around, proc { }, [:symbol], nil)
    end

    it 'should self-describe' do
      "#{Code}".should == 'Code'
    end
  end

  describe 'with parameters' do
    it 'should validate that the value is a Proc or Method' do
      contract = contract(Code[])
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [proc { }], nil)

      contract = contract(Code[])
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [self.method(:example)], nil)

      contract = contract(Code[], Code[])
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [proc { }, proc { }], nil)

      contract = contract(Code[])
      contract.should_receive(:failure).exactly(1).times
      contract.send(:around, proc { }, [:symbol], nil)
    end

    it 'should validate parameter constraints when the code is called' do
      contract = contract(Code[Fixnum])
      failures = 0
      Encase::Contract.any_instance.stub(:failure) { failures += 1 }

      callable = contract.wrap_callable(proc { |x| x[1] })
      callable[lambda { |y| y * 3 }].should == 3
      failures.should == 0

      callable = contract.wrap_callable(proc { |x| x['1'] })
      callable[lambda { |y| y * 3 }].should == '111'
      failures.should == 1
    end

    it 'should validate return value constraints when the code is called' do
      contract = contract(Code[Returns[Fixnum]])
      failures = 0
      Encase::Contract.any_instance.stub(:failure) { failures += 1 }

      callable = contract.wrap_callable(proc { |x| x[1] })
      callable[lambda { |y| y * 3 }].should == 3
      failures.should == 0

      callable[lambda { |y| y.to_s }].should == '1'
      failures.should == 1
    end

    it 'should self-describe' do
      "#{Code[]}".should == 'Code[]'
      "#{Code[Fixnum]}".should == 'Code[Fixnum]'
      "#{Code[Fixnum => Fixnum]}".should == 'Code[Fixnum => Fixnum]'
      "#{Code[Fixnum, Returns[Fixnum]]}".should == 'Code[Fixnum => Fixnum]'
      "#{Code[Returns[String]]}".should == 'Code[Returns[String]]'
    end
  end
end
end

describe "[Signature Constraints]" do
describe Encase::Contracts::Splat do
  Splat = Encase::Contracts::Splat

  def contract(*args)
    Encase::Contract.new(*args)
  end

  {
    "a simple splat" => [
      [ Splat[String] ], [
        [],
        ["1", "2", "3"],
      ]
    ],
    "a splat preceded by constraints" => [
      [ Fixnum, Symbol, Splat[String] ], [
        [1, :foo],
        [1, :foo, "string"],
        [1, :foo, "1", "2", "3"],
      ]
    ],
    "a splat followed by constraints" => [
      [ Splat[String], Fixnum, Symbol ], [
        [1, :foo],
        ["string", 1, :foo],
        ["1", "2", "3", 1, :foo],
      ]
    ],
  }.each do |name, spec|
    constraints, arguments = spec

    it "should match #{name} in a valid argument list" do
      arguments.each do |args|
        contract = contract(*constraints)
        contract.should_receive(:failure).exactly(0).times
        contract.send(:around, proc { }, [*args], nil)
      end
    end

    it "should match #{name} in a valid array" do
      arguments.each do |args|
        contract = contract(constraints)
        contract.should_receive(:failure).exactly(0).times
        contract.send(:around, proc { }, [args], nil)
      end
    end

    it "should match #{name} in a valid array in a hash" do
      arguments.each do |args|
        contract = contract(:a => 1, :b => constraints)
        contract.should_receive(:failure).exactly(0).times
        contract.send(:around, proc { }, [{ :a => 1, :b => args }], nil)
      end
    end
  end

  {
    "a simple splat" => [
      [ Splat[String] ], [
        [ [1, "2", "3"], [{ :value => 1 }] ],
        [ ["1", 2, "3"], [{ :value => 2 }] ],
        [ ["1", "2", 3], [{ :value => 3 }] ],
        [ [1, 2, 3],     [1, 2, 3].map { |v| {:value => v} } ],
      ]
    ],
    "a splat preceded by constraints" => [
      [ Fixnum, Symbol, Splat[String] ], [
        [ ['1', :f],   [{ :constraint => Fixnum, :value => '1' }] ],
        [ [1, 'f'],    [{ :constraint => Symbol, :value => 'f' }] ],
        [ [1, :f, :a, 'b', 'c'], [{ :value => :a }] ],
        [ [1, :f, 'a', :b, 'c'], [{ :value => :b }] ],
        [ [1, :f, 'a', 'b', :c], [{ :value => :c }] ],
        [ [1, :f, :a, :b, :c],   [:a, :b, :c].map { |v| { :value => v } } ],
      ]
    ],
    "a splat followed by constraints" => [
      [ Splat[String], Fixnum, Symbol ], [
        [ ['1', :f],   [{ :constraint => Fixnum, :value => '1' }] ],
        [ [1, 'f'],    [{ :constraint => Symbol, :value => 'f' }] ],
        [ [:a, 'b', 'c', 1, :f], [{ :value => :a }] ],
        [ ['a', :b, 'c', 1, :f], [{ :value => :b }] ],
        [ ['a', 'b', :c, 1, :f], [{ :value => :c }] ],
        [ [:a, :b, :c, 1, :f],   [:a, :b, :c].map { |v| { :value => v } } ],
      ]
    ],
  }.each do |name, spec|
    constraints, arguments = spec

    it "should fail to match #{name} in an invalid argument list" do
      arguments.each do |args, failures|
        contract = contract(*constraints)
        failures.each do |f|
          contract.should_receive(:failure).with(hash_including(f)) { true }
        end
        contract.send(:around, proc { }, [*args], nil)
      end
    end

    it "should fail to match #{name} in an invalid array" do
      arguments.each do |args, failures|
        contract = contract(constraints)
        failures.each do |f|
          contract.should_receive(:failure).with(hash_including(f)) { true }
        end
        contract.send(:around, proc { }, [args], nil)
      end
    end

    it "should fail to match #{name} in an invalid array in a hash" do
      arguments.each do |args, failures|
        contract = contract(:a => 1, :b => constraints)
        failures.each do |f|
          contract.should_receive(:failure).with(hash_including(f)) { true }
        end
        contract.send(:around, proc { }, [{ :a => 1, :b => args }], nil)
      end
    end
  end

  it 'should die when there is more than one splat in the argument list' do
    expect do
      contract(Splat[String], 1, :two, Splat[String], 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Splat[String], Splat[Fixnum])
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should die when there is more than one splat in an array' do
    expect do
      contract([ Splat[String], Splat[Fixnum] ])
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should die when there is more than one splat in a hash value' do
    expect do
      contract({ :a => :a, :b => [ Splat[String], Splat[Fixnum] ] })
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should die when used bare as a Hash value' do
    expect do
      contract(:a => Splat[Fixnum], :b => :b)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should not die when there is only one splat constraint per list' do
    expect do
      contract(Splat[ [Splat[Fixnum]] ])
    end.to_not raise_exception

    expect do
      contract({ :a => [ Splat[String] ] }, Splat[Fixnum])
    end.to_not raise_exception

    expect do
      contract(Splat[String], [ Splat[Fixnum] ])
    end.to_not raise_exception
  end

  it 'should raise an exception when not given a parameter' do
    expect do
      contract(1, :two, Splat, 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Splat)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract([Splat])
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(:a => [Splat], :b => :b)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should self-describe' do
    "#{Splat[Fixnum]}".should == 'Splat[Fixnum]'
    "#{Splat[Fixnum => Fixnum]}".should == 'Splat[{Fixnum=>Fixnum}]'
  end
end

describe Encase::Contracts::Block do
  Block = Encase::Contracts::Block

  def contract(*args)
    Encase::Contract.new(*args)
  end

  describe 'without parameters' do
    it 'should validate that the block exists' do
      contract = contract(Block)
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [], proc { })

      contract = contract(Block)
      contract.should_receive(:failure).exactly(1).times
      contract.send(:around, proc { }, [], nil)
    end

    it 'should self-describe' do
      "#{Block}".should == 'Block'
    end
  end

  describe 'with parameters' do
    it 'should validate that the block is a Proc or Method' do
      contract = contract(Block[])
      contract.should_receive(:failure).exactly(0).times
      contract.send(:around, proc { }, [], proc { })

      contract = contract(Block[])
      contract.should_receive(:failure).exactly(1).times
      contract.send(:around, proc { }, [], nil)
    end

    it 'should validate parameter constraints when the code is called' do
      contract = contract(Block[Fixnum])
      failures = 0
      Encase::Contract.any_instance.stub(:failure) { failures += 1 }

      callable = contract.wrap_callable(proc { |&x| x[1] })
      callable.call(&(lambda { |y| y * 3 })).should == 3
      failures.should == 0

      callable = contract.wrap_callable(proc { |&x| x['1'] })
      callable.call(&(lambda { |y| y * 3 })).should == '111'
      failures.should == 1
    end

    it 'should validate return value constraints when the code is called' do
      contract = contract(Block[Returns[Fixnum]])
      failures = 0
      Encase::Contract.any_instance.stub(:failure) { failures += 1 }

      callable = contract.wrap_callable(proc { |&x| x[1] })
      callable.call(&(lambda { |y| y * 3 })).should == 3
      failures.should == 0

      callable.call(&(lambda { |y| y.to_s })).should == '1'
      failures.should == 1
    end

    it 'should self-describe' do
      "#{Block[]}".should == 'Block[]'
      "#{Block[Fixnum]}".should == 'Block[Fixnum]'
      "#{Block[Fixnum => Fixnum]}".should == 'Block[Fixnum => Fixnum]'
      "#{Block[Fixnum, Returns[Fixnum]]}".should == 'Block[Fixnum => Fixnum]'
      "#{Block[Returns[String]]}".should == 'Block[Returns[String]]'
    end
  end
end

describe Encase::Contracts::Returns do
  Returns = Encase::Contracts::Returns

  def contract(*args)
    Encase::Contract.new(*args)
  end

  it 'should validate the returned value of a callable' do
    contract = contract(Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [], nil)

    contract = contract(Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [], nil)

    contract = contract(Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [1], nil)
  end

  it 'should validate even when preceded by other arguments' do
    contract = contract(1, :two, 'three', Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [1, :two, 'three'], nil)

    contract = contract(1, :two, 'three', Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [1, :two, 'three'], nil)
  end

  it 'should validate even when used incorrectly' do
    contract = contract(Symbol => Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [:two], nil)

    contract = contract(Symbol, Returns[Returns[String]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [:two], nil)
  end

  it 'should raise an exception when not the final constraint' do
    expect do
      contract(1, :two, Returns[String], 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Returns[String], nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract([ Returns[String] ])
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract({ :a => Returns[String] }, nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract({ :a => [Returns[String]] }, nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    # Wrong, but we should be forgiving.
    expect { contract(Fixnum => Returns[String]) }.to_not raise_exception

    # This should be obviously wrong, but we're still about being forgiving.
    expect { contract(Returns[Returns[String]]) }.to_not raise_exception
  end

  it 'should raise an exception when not given a parameter' do
    expect do
      contract(1, :two, Returns, 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Returns)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract([ Returns ])
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract({ :a => Returns }, nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract({ :a => [Returns] }, nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Fixnum => Returns)
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Returns[Returns])
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should self-describe' do
    "#{Returns[Fixnum]}".should == 'Returns[Fixnum]'
    "#{Returns[Fixnum => Fixnum]}".should == 'Returns[{Fixnum=>Fixnum}]'
    "#{Returns[Returns[String]]}".should == 'Returns[Returns[String]]'
  end
end
end
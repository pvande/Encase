require 'encase/contracts'

describe Encase::Contracts::Splat do
  OLD_RUBY = RUBY_VERSION =~ /^1\.8\./

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
        contract.send(:around, proc {}, [*args], nil)
      end
    end

    it "should match #{name} in a valid array" do
      arguments.each do |args|
        contract = contract(constraints)
        contract.should_receive(:failure).exactly(0).times
        contract.send(:around, proc {}, [args], nil)
      end
    end

    it "should match #{name} in a valid array in a hash" do
      arguments.each do |args|
        contract = contract(:a => 1, :b => constraints)
        contract.should_receive(:failure).exactly(0).times
        contract.send(:around, proc {}, [{ :a => 1, :b => args }], nil)
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
        contract.send(:around, proc {}, [*args], nil)
      end
    end

    it "should fail to match #{name} in an invalid array" do
      arguments.each do |args, failures|
        contract = contract(constraints)
        failures.each do |f|
          contract.should_receive(:failure).with(hash_including(f)) { true }
        end
        contract.send(:around, proc {}, [args], nil)
      end
    end

    it "should fail to match #{name} in an invalid array in a hash" do
      arguments.each do |args, failures|
        contract = contract(:a => 1, :b => constraints)
        failures.each do |f|
          contract.should_receive(:failure).with(hash_including(f)) { true }
        end
        contract.send(:around, proc {}, [{ :a => 1, :b => args }], nil)
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
  end

  it 'should validate even when preceded by other arguments' do
    contract = contract(1, :two, 'three', Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [1, :two, 'three'], nil)

    contract = contract(1, :two, 'three', Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [1, :two, 'three'], nil)
  end

  it 'should raise an exception when not the final constraint' do
    expect do
      contract(1, :two, Returns[String], 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Returns[String], nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should raise an exception when not given a parameter' do
    expect do
      contract(1, :two, Returns, 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Returns)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end
end

require 'spec_helper'
require 'encase/contracts'

def contract(*args)
  Encase::Contract.new(*args)
end

describe "[Abstract Type Constraints]" do
describe Encase::Contracts::Any do
  Any = Encase::Contracts::Any

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

describe "[Logical Type Constraints]" do
describe Encase::Contracts::And do
  And = Encase::Contracts::And

  it 'should validate any value that matches all given constraints' do
    contract = contract(And[Fixnum, (0..2)])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(And[String, /\d+/])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['1234'], nil)
  end

  it 'should destructure arguments' do
    contract = contract(And[{:a => Fixnum}, {:b => Fixnum}])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ {:a => 1, :b => 2} ], nil)
  end

  it 'should fail any value that does not meet all constraints' do
    contract = contract(And[String, /\d+/])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, ['xyz'], nil)

    contract = contract(And[Fixnum, (0..2)])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [1.0], nil)
  end

  it 'should validate the lack of any optional values' do
    And[None, None].should be_optional

    contract = contract(And[None, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [], nil)

    contract = contract(Fixnum, And[None, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(Fixnum, [And[None, None]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1, []], nil)
  end

  it 'should self-describe' do
    "#{And[Fixnum, String]}".should == 'And[Fixnum, String]'
    "#{And[Fixnum, "String", nil]}".should == 'And[Fixnum, "String", nil]'
    "#{And[Fixnum, {"String"=>nil}]}".should == 'And[Fixnum, {"String"=>nil}]'
  end
end

describe Encase::Contracts::Or do
  Or = Encase::Contracts::Or

  it 'should validate any value that matches any given constraint' do
    contract = contract(Or[Fixnum, String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, ['string'], nil)

    contract = contract(Or[String, Symbol, nil])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['1234'], nil)
    contract.send(:around, proc { }, [:counters], nil)
    contract.send(:around, proc { }, [nil], nil)

    contract = contract(Or[String, /\d+/])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['xyz'], nil)
    contract.send(:around, proc { }, ['1234'], nil)
  end

  it 'should destructure arguments' do
    contract = contract(Or[{:a => Fixnum}, {:b => Fixnum}])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ {:a => 1} ], nil)
    contract.send(:around, proc { }, [ {:b => 2} ], nil)
    contract.send(:around, proc { }, [ {:a => 1, :b => 2} ], nil)
  end

  it 'should validate the lack of any optional values' do
    Or[true, None].should be_optional

    contract = contract(Or[true, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [], nil)

    contract = contract(Fixnum, Or[true, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(Fixnum, [Or[true, None]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1, []], nil)
  end

  it 'should fail any value that does not meet any criteria' do
    contract = contract(Or[String, /\d+/])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [:xyz], nil)

    contract = contract(Or[Fixnum, (0..2)])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, ['1'], nil)
  end

  it 'should self-describe' do
    "#{Or[Fixnum, String]}".should == 'Or[Fixnum, String]'
    "#{Or[Fixnum, "String", nil]}".should == 'Or[Fixnum, "String", nil]'
    "#{Or[Fixnum, {"String"=>nil}]}".should == 'Or[Fixnum, {"String"=>nil}]'
  end
end

describe Encase::Contracts::Xor do
  Xor = Encase::Contracts::Xor

  it 'should validate any value that matches any one given constraint' do
    contract = contract(Xor[Fixnum, String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, ['string'], nil)

    contract = contract(Xor[String, Symbol, nil])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['1234'], nil)
    contract.send(:around, proc { }, [:counters], nil)
    contract.send(:around, proc { }, [nil], nil)
  end

  it 'should destructure arguments' do
    contract = contract(Xor[{:a => Fixnum}, {:b => Fixnum}])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ {:a => 1} ], nil)
    contract.send(:around, proc { }, [ {:b => 2} ], nil)

    contract = contract(Xor[{:a => 1}, {:b => 2}])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [ {:a => 1, :b => 2} ], nil)
  end

  it 'should validate the lack of any optional values' do
    Xor[true, None].should be_optional

    contract = contract(Xor[true, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [], nil)

    contract = contract(Fixnum, Xor[true, None])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(Fixnum, [Xor[true, None]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1, []], nil)
  end

  it 'should fail any value that does not meet any criteria' do
    contract = contract(Xor[String, /\d+/])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [:xyz], nil)

    contract = contract(Xor[Fixnum, (0..2)])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, ['1'], nil)
  end

  it 'should fail any value that meets more than one criteria' do
    contract = contract(Xor[Fixnum, (0..2)])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [1], nil)

    contract = contract(Xor[String, /\d+/, proc { |x| x.length > 3 }])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, ['1234'], nil)
  end

  it 'should self-describe' do
    "#{Xor[Fixnum, String]}".should == 'Xor[Fixnum, String]'
    "#{Xor[Fixnum, "String", nil]}".should == 'Xor[Fixnum, "String", nil]'
    "#{Xor[Fixnum, {"String"=>nil}]}".should == 'Xor[Fixnum, {"String"=>nil}]'
  end
end

describe Encase::Contracts::Not do
  Not = Encase::Contracts::Not

  it 'should validate any value that matches any given constraint' do
    contract = contract(Not[Fixnum])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['1'], nil)
    contract.send(:around, proc { }, [:symbol], nil)

    contract = contract(Not[/\d+/])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['xyz'], nil)
  end

  it 'should not destructure arguments' do
    contract = contract(Not[{:a => Fixnum}])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ {:a => 1} ], nil)

    contract = contract(Not[ [Fixnum] ])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ [1] ], nil)

    contract = contract({:a => Not[Fixnum]})
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [ {:a => 1} ], nil)

    contract = contract([Not[Fixnum]])
    contract.should_receive(:failure).with(hash_including :value => 1)
    contract.should_receive(:failure).with(hash_including :value => [1])
    contract.send(:around, proc { }, [ [1] ], nil)
  end

  it 'should fail any value that does not meet any criteria' do
    contract = contract(Not[String])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, ['xyz'], nil)

    contract = contract(Not[(0..2)])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [1], nil)
  end

  it 'should properly validate negated Code constraints' do
    contract = contract(Not[Code])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, ['xyz'], nil)

    contract = contract(Not[Code])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [proc { }], nil)
  end

  it 'should refuse to negate parameterized Code constraints' do
    expect do
      contract(Not[Code[Fixnum]])
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Not[Code[]])
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should self-describe' do
    "#{Not[Fixnum]}".should == 'Not[Fixnum]'
    "#{Not[nil]}".should == 'Not[nil]'
    "#{Not[{"String"=>nil}]}".should == 'Not[{"String"=>nil}]'
  end
end
end

describe "[Type Constraints]" do
describe Encase::Contracts::Int do
  Int = Encase::Contracts::Int

  it 'should match all valid integers' do
    contract = contract(Int)
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [0], nil)
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [-1], nil)
    contract.send(:around, proc { }, [9999999999999999999], nil)
    contract.send(:around, proc { }, [-9999999999999999999], nil)
  end

  it 'should refuse all non-integers' do
    contract = contract(Int)
    contract.should_receive(:failure).exactly(7).times
    contract.send(:around, proc { }, [Object.new], nil)
    contract.send(:around, proc { }, ['0'], nil)
    contract.send(:around, proc { }, [0.0], nil)
    contract.send(:around, proc { }, [1.0], nil)
    contract.send(:around, proc { }, [-1.0], nil)
    contract.send(:around, proc { }, [ 1 / 0.0], nil)  # Infinity
    contract.send(:around, proc { }, [-1 / 0.0], nil)  # -Infinity
  end
end

describe Encase::Contracts::Num do
  Num = Encase::Contracts::Num

  it 'should match all valid numbers' do
    contract = contract(Num)
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [0], nil)
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [1.0], nil)
    contract.send(:around, proc { }, [1.5], nil)
    contract.send(:around, proc { }, [-1], nil)
    contract.send(:around, proc { }, [-1.0], nil)
    contract.send(:around, proc { }, [ 1 / 0.0], nil)  # Infinity
    contract.send(:around, proc { }, [-1 / 0.0], nil)  # -Infinity
  end

  it 'should refuse all non-numbers' do
    contract = contract(Num)
    contract.should_receive(:failure).exactly(6).times
    contract.send(:around, proc { }, [Object.new], nil)
    contract.send(:around, proc { }, [nil], nil)
    contract.send(:around, proc { }, ['0'], nil)
    contract.send(:around, proc { }, [:symbol], nil)
    contract.send(:around, proc { }, [ [1] ], nil)
    contract.send(:around, proc { }, [ { } ], nil)
  end
end

describe Encase::Contracts::Bool do
  Bool = Encase::Contracts::Bool

  it 'should match all valid booleans' do
    contract = contract(Bool)
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [true], nil)
    contract.send(:around, proc { }, [false], nil)
  end

  it 'should refuse all non-booleans' do
    contract = contract(Bool)
    contract.should_receive(:failure).exactly(5).times
    contract.send(:around, proc { }, [nil], nil)
    contract.send(:around, proc { }, ['true'], nil)
    contract.send(:around, proc { }, [:symbol], nil)
    contract.send(:around, proc { }, [ [1] ], nil)
    contract.send(:around, proc { }, [ { } ], nil)
  end

  it 'should self-describe' do
    "#{Bool}".should == 'Bool'
  end
end

describe Encase::Contracts::Code do
  Code = Encase::Contracts::Code

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

describe "[Dynamic Constraints]" do
describe Encase::Contracts::Test do
  Test = Encase::Contracts::Test

  it 'should validate all values who return a truthy value for the test' do
    contract = contract(Test[:empty?])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [[]], nil)
    contract.send(:around, proc { }, [{}], nil)
    contract.send(:around, proc { }, [''], nil)

    contract = contract(Test[:zero?])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [0], nil)
  end

  it 'should refuse all values who return a falsey value for the test' do
    contract = contract(Test[:empty])
    contract.should_receive(:failure).exactly(3).times
    contract.send(:around, proc { }, [[1]], nil)
    contract.send(:around, proc { }, [{:a => 1}], nil)
    contract.send(:around, proc { }, ['abc'], nil)

    contract = contract(Test[:zero?])
    contract.should_receive(:failure).exactly(3).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [nil], nil)
    contract.send(:around, proc { }, [:symbol], nil)
  end

  it 'should pass extra arguments along with the message send' do
    contract = contract(Test[:>, 0])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [2], nil)
    contract.send(:around, proc { }, [1 / 0.0], nil)  # Infinity

    contract = contract(Test[:<, 0])
    contract.should_receive(:failure).exactly(3).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [2], nil)
    contract.send(:around, proc { }, [1 / 0.0], nil)  # Infinity
  end

  it 'should self-describe' do
    "#{Test[:true?]}".should == 'Test[:true?]'
    "#{Test[:>, 0]}".should == 'Test[:>, 0]'
  end
end

describe Encase::Contracts::Can do
  Can = Encase::Contracts::Can

  it 'should validate all values who respond to the named method' do
    contract = contract(Can[:each])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [[]], nil)
    contract.send(:around, proc { }, [{}], nil)

    contract = contract(Can[:zero?])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [0], nil)
    contract.send(:around, proc { }, [1], nil)
  end

  it 'should refuse all values who do not respond to the named method' do
    contract = contract(Can[:die_horribly])
    contract.should_receive(:failure).exactly(3).times
    contract.send(:around, proc { }, [[1]], nil)
    contract.send(:around, proc { }, [{:a => 1}], nil)
    contract.send(:around, proc { }, ['abc'], nil)

    contract = contract(Can[:zero?])
    contract.should_receive(:failure).exactly(3).times
    contract.send(:around, proc { }, [nil], nil)
    contract.send(:around, proc { }, [:symbol], nil)
    contract.send(:around, proc { }, [double()], nil)
  end

  it 'should test all named methods' do
    contract = contract(Can[:>, :<, :===, :==])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [1], nil)
    contract.send(:around, proc { }, [2], nil)
    contract.send(:around, proc { }, [1 / 0.0], nil)  # Infinity

    contract = contract(Can[:>, :<, :===, :==])
    contract.should_receive(:failure).exactly(2).times
    contract.send(:around, proc { }, [Class.new.new], nil)
    contract.send(:around, proc { }, [double()], nil)
  end

  it 'should self-describe' do
    "#{Can[:true?]}".should == 'Can[:true?]'
    "#{Can[:to_proc, :to_s]}".should == 'Can[:to_proc, :to_s]'
  end
end

describe Encase::Contracts::List do
  List = Encase::Contracts::List

  it 'should validate arrays whose elements each match any given type' do
    contract = contract(List[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ [] ], nil)
    contract.send(:around, proc { }, [ ['a'] ], nil)
    contract.send(:around, proc { }, [ %w[one two three] ], nil)

    contract = contract(List[String, Fixnum])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ ['a', 'b', 'c'] ], nil)
    contract.send(:around, proc { }, [ [1, 2, 3] ], nil)
    contract.send(:around, proc { }, [ [1, '2', 3] ], nil)
  end

  it 'should reject arrays whose elements do not all match any given type' do
    contract = contract(List[String])
    contract.should_receive(:failure).exactly(2).times
    contract.send(:around, proc { }, [ [1] ], nil)
    contract.send(:around, proc { }, [ ['one', 'two', :three] ], nil)

    contract = contract(List[String, Fixnum])
    contract.should_receive(:failure).exactly(2).times
    contract.send(:around, proc { }, [ ['a', 'b', :c] ], nil)
    contract.send(:around, proc { }, [ [1, :two, 3] ], nil)
  end

  it 'should validate hashes whose elements each match any given type' do
    contract = contract(List[[String, Fixnum]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ { 'a' => 1, 'b' => 2 } ], nil)
    contract.send(:around, proc { }, [ { } ], nil)

    contract = contract(List[[String, Fixnum], [Symbol, Symbol]])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ { 'a' => 1, 'b' => 2, 'c' => 3 } ], nil)
    contract.send(:around, proc { }, [ { :a => :a, :b => :b, :c => :c } ], nil)
    contract.send(:around, proc { }, [ { 'a' => 1, :b => :b, 'c' => 3 } ], nil)
  end

  it 'should reject hashes whose elements do not all match any given type' do
    contract = contract(List[[String, Fixnum]])
    contract.should_receive(:failure).exactly(2).times
    contract.send(:around, proc { }, [ { :a => 1, 'b' => 2 } ], nil)
    contract.send(:around, proc { }, [ { 'a' => 1, 'b' => '2' } ], nil)

    contract = contract(List[[String, Fixnum], [Symbol, Symbol]])
    contract.should_receive(:failure).exactly(4).times
    contract.send(:around, proc { }, [ {'a' => 1, :b => 2, 'c' => 3} ], nil)
    contract.send(:around, proc { }, [ {:a => :a, :b => 'b', :c => :c} ], nil)
    contract.send(:around, proc { }, [ {'a' => :a, :b => :b, 'c' => 3} ], nil)
    contract.send(:around, proc { }, [ {1 => 'a', :b => :b, 'c' => 3} ], nil)
  end

  it 'should validate any Enumerable whose elements all match' do
    contract = contract(List[proc { |x| x.length < 3 }])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { }, [ ('a'...'aaa') ], nil)
  end

  it 'should reject any Enumerable whose elements do not all match' do
    contract = contract(List[proc { |x| x.length < 3 }])
    contract.should_receive(:failure).exactly(1).times
    contract.send(:around, proc { }, [ ('a'..'zzz') ], nil)
  end

  it 'should self-describe' do
    "#{List[String]}".should == 'List[String]'
    "#{List[Fixnum, String]}".should == 'List[Fixnum, String]'
  end
end
end

describe "[Signature Constraints]" do
describe Encase::Contracts::Splat do
  Splat = Encase::Contracts::Splat

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
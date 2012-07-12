require 'spec_helper'
require 'encase'

class IntegrationPoint
  include Encase::Contracts

  Contract String
  def self.no_return_validation(str)
    str =~ /^\d+$/ ? str.to_i(10) : str
  end

  Contract Fixnum => Fixnum
  def double(x)
    x * 2
  end

  def unannotated_double(x)
    x * 2
  end

  Contract Fixnum, Fixnum => Fixnum
  def self.add(x, y)
    x + y
  end

  Contract Fixnum, [String, Regexp] => [Fixnum]
  def array_destructuring(n, arr)
    arr.each { |s,re| s =~ re }
    return [double(n)]
  end

  Contract Fixnum, { :str => String, :re => Regexp } => [Fixnum]
  def hash_destructuring(n, hash)
    hash[:str] =~ hash[:re]
    return [double(n)]
  end

  Contract Fixnum, { :str => String, :re => Regexp }
  def options_destructuring(n, opts)
    n.times { opts[:str] =~ opts[:re] }
  end

  Contract Splat[Fixnum] => Fixnum
  def sum(*args)
    args.inject(0) { |a,b| a + b }
  end
end

module IntegrationModule
  include Encase::Contracts

  Contract Int => Int
  def triple(n)
    n * 3
  end

  Contract Num, Num => Num
  def self.multiply(n, m)
    n * m
  end
end

top_level = self
describe 'the top-level context' do
  it 'should refuse to allow me to include decorators' do
    expect { top_level.send(:include, Encase::Contracts) }.to raise_exception
  end
end

describe IntegrationModule do
  it 'should allow valid calls to class methods' do
    expect do
      subject.multiply(1, 2).should == 2
      subject.multiply(3, 20).should == 60
    end.to_not raise_exception
  end

  it 'should disallow invalid calls to class methods' do
    expect { subject.multiply('1', '2') }.to raise_exception
    expect { subject.multiply([1], [2]) }.to raise_exception
  end

  describe '(included in a class)' do
    subject { Class.new { include IntegrationModule }.new }

    it 'should allow valid calls to instance methods' do
      expect do
        subject.triple(1).should == 3
        subject.triple(5).should == 15
      end.to_not raise_exception
    end
  end
end

describe IntegrationPoint do
  it 'should allow valid calls to class methods' do
    expect do
      subject.class.add(1, 2).should == 3
      subject.class.add(3, 20).should == 23
      subject.class.no_return_validation('10').should == 10
      subject.class.no_return_validation('x').should == 'x'
    end.to_not raise_exception
  end

  it 'should allow valid calls to instance methods' do
    expect do
      subject.double(1).should == 2
      subject.double(5).should == 10
      subject.array_destructuring(2, ['x', /f/]).should == [4]
      subject.hash_destructuring(4, { :str => 'x', :re => /f/ }).should == [8]
      subject.hash_destructuring(4, { :str => 'x', :re => /f/, :x => :y }).should == [8]
      subject.options_destructuring(3, :str => 'x', :re => /f/).should == 3
      subject.options_destructuring(3, :str => 'x', :re => /f/, :x => :y).should == 3
      subject.sum().should == 0
      subject.sum(1).should == 1
      subject.sum(1, 2, 3).should == 6
    end.to_not raise_exception
  end

  it 'should allow valid calls to undecorated methods' do
    expect do
      subject.unannotated_double(2).should == 4
      subject.unannotated_double([2]).should == [2, 2]
      subject.unannotated_double('2').should == '22'
    end.to_not raise_exception
  end

  it 'should disallow invalid calls to class methods' do
    expect { subject.class.add('1', '2') }.to raise_exception
    expect { subject.class.add([1], [2]) }.to raise_exception
  end

  it 'should disallow invalid calls to instance methods' do
    expect { subject.double(1, 2) }.to raise_exception
    expect { subject.double() }.to raise_exception
    expect { subject.double('1') }.to raise_exception
    expect { subject.double([1]) }.to raise_exception

    expect { subject.array_destructuring(2) }.to raise_exception
    expect { subject.array_destructuring(['x', /f/]) }.to raise_exception
    expect { subject.array_destructuring('2', ['x', /f/]) }.to raise_exception
    expect { subject.array_destructuring(2, [:x, /f/]) }.to raise_exception
    expect { subject.array_destructuring(2, ['x', 'f']) }.to raise_exception
    expect { subject.array_destructuring(2, ['x']) }.to raise_exception
    expect { subject.array_destructuring(2, ['x', /f/, 2]) }.to raise_exception
    expect { subject.array_destructuring(2, ['x', /f/, nil]) }.to raise_exception

    expect { subject.hash_destructuring(2) }.to raise_exception
    expect { subject.hash_destructuring({ :str => 'x', :re => /f/ }) }.to raise_exception
    expect { subject.hash_destructuring('2', { :str => 'x', :re => /f/ }) }.to raise_exception
    expect { subject.hash_destructuring(2, { :str => :x, :re => /f/ }) }.to raise_exception
    expect { subject.hash_destructuring(2, { :str => 'x', :re => 'f' }) }.to raise_exception
    expect { subject.hash_destructuring(2, { :str => 'x' }) }.to raise_exception
    expect { subject.hash_destructuring(2, { :re => /f/ }) }.to raise_exception

    expect { subject.options_destructuring(2) }.to raise_exception
    expect { subject.options_destructuring({ :str => 'x', :re => /f/ }) }.to raise_exception
    expect { subject.options_destructuring('2', { :str => 'x', :re => /f/ }) }.to raise_exception
    expect { subject.options_destructuring(2, { :str => :x, :re => /f/ }) }.to raise_exception
    expect { subject.options_destructuring(2, { :str => 'x', :re => 'f' }) }.to raise_exception
    expect { subject.options_destructuring(2, { :str => 'x' }) }.to raise_exception
    expect { subject.options_destructuring(2, { :re => /f/ }) }.to raise_exception

    expect { subject.sum([1, 2, 3]) }.to raise_exception
    expect { subject.sum('1') }.to raise_exception
    expect { subject.sum(1, 2, '3') }.to raise_exception
  end
end

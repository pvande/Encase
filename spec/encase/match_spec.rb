require 'spec_helper'
require 'encase/match'

describe Encase::Match do
  before do
    class PatternMatchingTest
      include Encase::PatternMatching

      Match Contract Or[0, 1] => Int
      def self.fib(n)
        return n
      end

      Match Contract Int, Block[Returns[Int]] => Int
      def self.fib(n, &b)
        return n * b[]
      end

      Match Contract And[Int, Test[:>, 1]] => Int
      def self.fib(n)
        return fib(n - 1) + fib(n - 2)
      end
    end
  end

  after { Object.send :remove_const, :PatternMatchingTest }

  subject { PatternMatchingTest }

  it { subject.fib(0).should == 0 }
  it { subject.fib(1).should == 1 }
  it { subject.fib(2).should == 1 }
  it { subject.fib(3).should == 2 }
  it { subject.fib(4).should == 3 }
  it { subject.fib(5).should == 5 }
  it { subject.fib(6).should == 8 }
  it { subject.fib(6) { -1 }.should == -6 }
end

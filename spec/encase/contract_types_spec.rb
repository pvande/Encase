require 'encase/contracts'

describe Encase::Contracts::Returns do
  def contract(*args)
    Encase::Contract.new(*args)
  end

  it 'should validate the returned value of a callable' do
    contract = contract(Encase::Contracts::Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [], nil)

    contract = contract(Encase::Contracts::Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [], nil)
  end

  it 'should validate even when preceded by other arguments' do
    contract = contract(1, :two, 'three', Encase::Contracts::Returns[String])
    contract.should_receive(:failure).exactly(0).times
    contract.send(:around, proc { "stringy" }, [1, :two, 'three'], nil)

    contract = contract(1, :two, 'three', Encase::Contracts::Returns[String])
    contract.should_receive(:failure).with(hash_including :value => :symbolic)
    contract.send(:around, proc { :symbolic }, [1, :two, 'three'], nil)
  end

  it 'should raise an exception when not the final constraint' do
    expect do
      contract(1, :two, Encase::Contracts::Returns[String], 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Encase::Contracts::Returns[String], nil)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end

  it 'should raise an exception when not given a parameter' do
    expect do
      contract(1, :two, Encase::Contracts::Returns, 'three')
    end.to raise_exception(Encase::Contract::MalformedContractError)

    expect do
      contract(Encase::Contracts::Returns)
    end.to raise_exception(Encase::Contract::MalformedContractError)
  end
end
